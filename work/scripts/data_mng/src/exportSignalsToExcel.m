function result = exportSignalsToExcel(modelName, varargin)
% exportSignalsToExcel  Export top-level I/O signals to Excel
%   Exports all Inport/Outport blocks with signal names, data types,
%   dimensions, and naming convention compliance info.
%
%   Inputs:
%       modelName  - Model name or path (.slx)
%       varargin   - 'OutputFile' - custom Excel output path
%                    'IncludeNested' - include subsystem ports (default: false)
%
%   Usage:
%       result = exportSignalsToExcel('Model.slx');
%       result = exportSignalsToExcel('Model.slx', 'OutputFile', 'signals.xlsx');

    fprintf('=== Export Signals to Excel ===\n\n');
    result = struct('inputCount', 0, 'outputCount', 0, 'outputFile', '', 'ports', {});

    %% Parse inputs
    p = inputParser;
    addRequired(p, 'modelName', @(x) ischar(x) || isstring(x));
    addParameter(p, 'OutputFile', '', @ischar);
    addParameter(p, 'IncludeNested', false, @islogical);
    parse(p, modelName, varargin{:});

    modelName = char(p.Results.modelName);
    outputFile = p.Results.OutputFile;
    includeNested = p.Results.IncludeNested;

    [modelDir, modelBase, ~] = fileparts(modelName);
    if isempty(modelDir), modelDir = pwd; modelBase = modelName; end

    if isempty(outputFile)
        outputFile = fullfile(modelDir, [modelBase '_signals.xlsx']);
    end

    %% Load model and find ports
    fprintf('[1/3] Scanning model ports...\n');
    load_system(modelBase);

    if includeNested
        searchDepth = 'all';
        inports = find_system(modelBase, 'LookUnderMasks', 'all', 'BlockType', 'Inport');
        outports = find_system(modelBase, 'LookUnderMasks', 'all', 'BlockType', 'Outport');
    else
        inports = find_system(modelBase, 'SearchDepth', 1, 'BlockType', 'Inport');
        outports = find_system(modelBase, 'SearchDepth', 1, 'BlockType', 'Outport');
    end

    %% Collect port info
    ports = {};
    typePrefixes = {'s8','s16','s32','s64','u8','u16','u32','u64','f32','f64','f16','b','bool'};

    % Process Inports
    for i = 1:numel(inports)
        blk = inports{i};
        if strcmp(blk, modelBase), continue; end
        info = getPortInfo(blk, 'Input', typePrefixes);
        if ~isempty(info), ports{end+1} = info; end %#ok<AGROW>
    end

    % Process Outports
    for i = 1:numel(outports)
        blk = outports{i};
        if strcmp(blk, modelBase), continue; end
        info = getPortInfo(blk, 'Output', typePrefixes);
        if ~isempty(info), ports{end+1} = info; end %#ok<AGROW>
    end

    inCount = sum(arrayfun(@(p) strcmp(p.direction, 'Input'), ports));
    outCount = sum(arrayfun(@(p) strcmp(p.direction, 'Output'), ports));
    fprintf('      Found %d inputs, %d outputs\n', inCount, outCount);
    result.inputCount = inCount;
    result.outputCount = outCount;
    result.ports = ports;

    if isempty(ports)
        fprintf('      No ports found.\n');
        result.outputFile = '';
        return;
    end

    %% Write to Excel
    fprintf('[2/3] Writing to Excel: %s\n', outputFile);
    writeSignalsToExcel(ports, outputFile);

    %% Summary
    fprintf('[3/3] Done.\n');
    fprintf('\n=== Export Complete ===\n');
    fprintf('Signals exported: %d (In: %d, Out: %d)\n', numel(ports), inCount, outCount);
    fprintf('Output: %s\n', outputFile);
    result.outputFile = outputFile;

    % Preview
    fprintf('\n--- Preview (first 10) ---\n');
    fprintf('%-25s %-8s %-12s %-12s %s\n', 'Name', 'Dir', 'DataType', 'TypePrefix', 'Path');
    for i = 1:min(10, numel(ports))
        p = ports{i};
        fprintf('%-25s %-8s %-12s %-12s %s\n', p.name, p.direction, p.dataType, p.prefixStatus, p.path);
    end
end

function info = getPortInfo(blockPath, direction, typePrefixes)
% Extract port information
    info = [];
    try
        name = get_param(blockPath, 'Name');
        dt = get_param(blockPath, 'OutDataTypeStr');
        dims = get_param(blockPath, 'Dimensions');
        st = get_param(blockPath, 'SampleTime');

        % Get connected signal name
        sigName = '';
        try
            lineHandle = get_param(blockPath, 'LineHandles');
            if direction == "Input"
                lh = lineHandle.Outport;
            else
                lh = lineHandle.Inport;
            end
            if lh ~= -1
                sigName = get_param(lh, 'Name');
            end
        catch, end

        % Check naming convention compliance
        prefixStatus = '无前缀';
        for t = 1:numel(typePrefixes)
            p = typePrefixes{t};
            if startsWith(name, p)
                rest = name(length(p)+1:end);
                if ~isempty(rest) && isletter(rest(1))
                    dtFromName = typeMapDirect(p);
                    if strcmp(dtFromName, dt) || contains(dt, 'Inherit')
                        prefixStatus = ['✅ ' p];
                    else
                        prefixStatus = ['⚠ ' p '→' dtFromName '(实际:' dt ')'];
                    end
                    break;
                end
            end
        end

        info = struct();
        info.name = name;
        info.direction = direction;
        info.dataType = dt;
        info.dimensions = dims;
        info.sampleTime = st;
        info.signalName = sigName;
        info.prefixStatus = prefixStatus;
        info.path = blockPath;
    catch
    end
end

function dt = typeMapDirect(prefix)
    m = containers.Map();
    m('s8')='int8'; m('s16')='int16'; m('s32')='int32'; m('s64')='int64';
    m('u8')='uint8'; m('u16')='uint16'; m('u32')='uint32'; m('u64')='uint64';
    m('f32')='single'; m('f64')='double'; m('f16')='half';
    m('b')='boolean'; m('bool')='boolean';
    if isKey(m, prefix), dt = m(prefix); else, dt = ''; end
end

function writeSignalsToExcel(ports, outputFile)
% Write signal data to Excel
    headers = {'PortName', 'Direction', 'DataType', 'Dimensions', 'SampleTime', ...
               'ConnectedSignal', 'NamingStatus', 'FullPath'};
    n = numel(ports);
    data = cell(n, numel(headers));
    for i = 1:n
        p = ports{i};
        data{i,1} = p.name;
        data{i,2} = p.direction;
        data{i,3} = p.dataType;
        data{i,4} = p.dimensions;
        data{i,5} = p.sampleTime;
        data{i,6} = p.signalName;
        data{i,7} = p.prefixStatus;
        data{i,8} = p.path;
    end
    outTable = cell2table(data, 'VariableNames', headers);
    writetable(outTable, outputFile, 'Sheet', 'Signals');
end
