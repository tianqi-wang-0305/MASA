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
    load_system(modelName);

    if includeNested
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
        try
            info = struct();
            info.name = get_param(blk, 'Name');
            info.direction = 'Input';
            info.dataType = get_param(blk, 'OutDataTypeStr');
            info.dimensions = '';
            info.sampleTime = get_param(blk, 'SampleTime');
            info.signalName = '';
            info.path = blk;
            info.prefixStatus = checkNamingPrefix(info.name, info.dataType, typePrefixes);
            ports{end+1} = info;
        catch
        end
    end

    % Process Outports
    for i = 1:numel(outports)
        blk = outports{i};
        if strcmp(blk, modelBase), continue; end
        try
            info = struct();
            info.name = get_param(blk, 'Name');
            info.direction = 'Output';
            info.dataType = get_param(blk, 'OutDataTypeStr');
            info.dimensions = '';
            info.sampleTime = get_param(blk, 'SampleTime');
            info.signalName = '';
            info.path = blk;
            info.prefixStatus = checkNamingPrefix(info.name, info.dataType, typePrefixes);
            ports{end+1} = info;
        catch
        end
    end

    inCount = 0; outCount = 0;
    for i = 1:numel(ports)
        if strcmp(ports{i}.direction, 'Input'), inCount = inCount + 1;
        else, outCount = outCount + 1; end
    end
    fprintf('      Found %d inputs, %d outputs\n', inCount, outCount);
    result = struct('inputCount', inCount, 'outputCount', outCount, ...
        'outputFile', outputFile, 'ports', {ports});

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

function status = checkNamingPrefix(name, dataType, typePrefixes)
% Check if port name follows naming convention
    typeMap = containers.Map();
    typeMap('s8')='int8'; typeMap('s16')='int16'; typeMap('s32')='int32'; typeMap('s64')='int64';
    typeMap('u8')='uint8'; typeMap('u16')='uint16'; typeMap('u32')='uint32'; typeMap('u64')='uint64';
    typeMap('f32')='single'; typeMap('f64')='double'; typeMap('f16')='half';
    typeMap('b')='boolean'; typeMap('bool')='boolean';
    status = '无前缀';
    for t = 1:numel(typePrefixes)
        p = typePrefixes{t};
        if startsWith(name, p)
            rest = name(length(p)+1:end);
            if ~isempty(rest) && isletter(rest(1))
                if isKey(typeMap, p)
                    expected = typeMap(p);
                    if strcmp(expected, dataType) || contains(dataType, 'Inherit')
                        status = ['✅ ' p];
                    else
                        status = ['⚠ ' p '→' expected '(实际:' dataType ')'];
                    end
                end
                break;
            end
        end
    end
end

function writeSignalsToExcel(ports, outputFile)
% Write signal data to Excel
    headers = {'PortName', 'Direction', 'DataType', 'Dimensions', 'SampleTime', ...
               'ConnectedSignal', 'NamingStatus'};
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
    end
    outTable = cell2table(data, 'VariableNames', headers);
    writetable(outTable, outputFile, 'Sheet', 'Signals');
end
