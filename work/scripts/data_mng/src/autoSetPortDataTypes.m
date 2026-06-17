function result = autoSetPortDataTypes(modelName, varargin)
% autoSetPortDataTypes  Auto-set port data types from signal name prefixes
%   Scans all Inport/Outport blocks (recursively through subsystems) and
%   sets their data type based on the signal name prefix convention.
%
%   Signal naming convention: {type}{Description}
%     s8Name    → int8        u8Name     → uint8
%     s16Name   → int16       u16Name    → uint16
%     s32Name   → int32       u32Name    → uint32
%     f32Name   → single      f64Name    → double
%     bName     → boolean     boolName   → boolean
%     No prefix → Inherit (auto)
%
%   Inputs:
%       modelName  - Model name or path (.slx)
%       varargin   - 'Scope' - subsystem to scan (default: whole model)
%                    'DryRun' - preview only, don't apply (default: false)
%                    'MappingFile' - custom prefix→type JSON (default: built-in)
%
%   Outputs:
%       result     - Struct with changed blocks, counts, errors
%
%   Usage:
%       % Preview changes only
%       result = autoSetPortDataTypes('Model.slx', 'DryRun', true);
%
%       % Apply to whole model
%       result = autoSetPortDataTypes('Model.slx');
%
%       % Apply to specific subsystem only
%       result = autoSetPortDataTypes('Model.slx', 'Scope', 'Model/Subsystem');

    fprintf('=== Auto-Set Port Data Types from Signal Names ===\n\n');
    result = struct('changed', {{}}, 'skipped', {{}}, 'errors', {{}}, ...
        'totalInports', 0, 'totalOutports', 0, 'changedCount', 0, ...
        'reportFile', '');

    %% Parse inputs
    p = inputParser;
    addRequired(p, 'modelName', @(x) ischar(x) || isstring(x));
    addParameter(p, 'Scope', '', @ischar);
    addParameter(p, 'DryRun', false, @islogical);
    addParameter(p, 'MappingFile', '', @ischar);
    parse(p, modelName, varargin{:});

    modelName = char(p.Results.modelName);
    scope = p.Results.Scope;
    dryRun = p.Results.DryRun;
    mappingFile = p.Results.MappingFile;

    [modelDir, modelBase, modelExt] = fileparts(modelName);
    if isempty(modelDir)
        modelDir = pwd;
    end
    if isempty(modelExt)
        modelFile = fullfile(modelDir, [modelBase '.slx']);
    else
        modelFile = fullfile(modelDir, [modelBase modelExt]);
    end
    if isempty(modelBase)
        [~, modelBase] = fileparts(modelFile);
    end

    %% Load prefix→type mapping
    prefixMap = loadPrefixMapping(mappingFile);
    printMapping(prefixMap);

    %% Load model
    fprintf('\n[1/3] Loading model: %s\n', modelBase);
    load_system(modelFile);

    %% Find all ports recursively
    fprintf('[2/3] Scanning ports...\n');

    if isempty(scope)
        searchRoot = modelBase;
    else
        searchRoot = scope;
    end

    % Find all Inport and Outport blocks at all levels
    allInports = find_system(searchRoot, 'LookUnderMasks', 'all', ...
        'FollowLinks', 'on', 'BlockType', 'Inport');
    allOutports = find_system(searchRoot, 'LookUnderMasks', 'all', ...
        'FollowLinks', 'on', 'BlockType', 'Outport');

    % Filter out the root scope itself (sometimes returned by find_system)
    inports = {};
    for i = 1:numel(allInports)
        if ~strcmp(allInports{i}, searchRoot)
            inports{end+1} = allInports{i}; %#ok<AGROW>
        end
    end
    outports = {};
    for i = 1:numel(allOutports)
        if ~strcmp(allOutports{i}, searchRoot)
            outports{end+1} = allOutports{i}; %#ok<AGROW>
        end
    end

    result.totalInports = numel(inports);
    result.totalOutports = numel(outports);
    fprintf('      Found %d Inports, %d Outports\n', numel(inports), numel(outports));

    %% Process ports
    fprintf('[3/3] Processing ports...\n');

    changed = {};
    skipped = {};
    errors = {};

    % Process Inports
    for i = 1:numel(inports)
        [c, s, e] = processPort(inports{i}, 'Inport', prefixMap, dryRun);
        changed = [changed; c(:)]; %#ok<AGROW>
        skipped = [skipped; s(:)]; %#ok<AGROW>
        errors = [errors; e(:)]; %#ok<AGROW>
    end

    % Process Outports
    for i = 1:numel(outports)
        [c, s, e] = processPort(outports{i}, 'Outport', prefixMap, dryRun);
        changed = [changed; c(:)]; %#ok<AGROW>
        skipped = [skipped; s(:)]; %#ok<AGROW>
        errors = [errors; e(:)]; %#ok<AGROW>
    end

    result.changed = changed;
    result.skipped = skipped;
    result.errors = errors;
    result.changedCount = numel(changed);

    if ~dryRun
        fprintf('\nSaving model: %s\n', modelBase);
        save_system(modelBase);
    end

    %% Summary
    fprintf('\n=== Summary ===\n');
    fprintf('Total ports: %d (In: %d, Out: %d)\n', ...
        numel(inports) + numel(outports), numel(inports), numel(outports));
    fprintf('Changed:     %d\n', numel(changed));
    fprintf('Skipped:     %d\n', numel(skipped));
    fprintf('Errors:      %d\n', numel(errors));

    if dryRun
        fprintf('\n⚠ DRY RUN — no changes applied. Re-run without DryRun to apply.\n');
    end

    %% Print details
    if ~isempty(changed)
        fprintf('\n--- Changed Ports ---\n');
        for i = 1:min(20, numel(changed))
            c = changed{i};
            fprintf('  ✅ %s → %s\n', c.path, c.newType);
        end
        if numel(changed) > 20
            fprintf('  ... and %d more\n', numel(changed) - 20);
        end
    end
    if ~isempty(skipped)
        fprintf('\n--- Skipped (no prefix match or already correct) ---\n');
        for i = 1:min(10, numel(skipped))
            s = skipped{i};
            fprintf('  ⏭ %s (reason: %s)\n', s.path, s.reason);
        end
        if numel(skipped) > 10
            fprintf('  ... and %d more\n', numel(skipped) - 10);
        end
    end

    %% Generate HTML report
    result.reportFile = generatePortReport(result, modelBase, dryRun);
    fprintf('\nReport: %s\n', result.reportFile);
end

function reportFile = generatePortReport(result, modelName, dryRun)
    reportFile = fullfile(pwd, [modelName '_port_types_report.html']);
    fid = fopen(reportFile, 'w');
    fprintf(fid, '<!DOCTYPE html><html><head>\n<meta charset="UTF-8">\n');
    fprintf(fid, '<title>Port Data Type Report - %s</title>\n', modelName);
    fprintf(fid, '<style>body{font-family:-apple-system,sans-serif;margin:40px}\n');
    fprintf(fid, 'h1{color:#333;border-bottom:2px solid #9C27B0;padding-bottom:10px}\n');
    fprintf(fid, '.changed{background:#e8f5e9}.skipped{background:#f5f5f5}.err{background:#ffebee}\n');
    fprintf(fid, 'table{border-collapse:collapse;width:100%%;margin:20px 0;font-size:13px}\n');
    fprintf(fid, 'th,td{border:1px solid #ddd;padding:8px;text-align:left}\n');
    fprintf(fid, 'th{background:#9C27B0;color:white}\n');
    fprintf(fid, '.badge{display:inline-block;padding:2px 8px;border-radius:10px;font-size:11px;color:white}\n');
    fprintf(fid, '.badge-ok{background:#4CAF50}.badge-skip{background:#9E9E9E}.badge-err{background:#f44336}\n');
    fprintf(fid, '.summary{background:#f3e5f5;padding:20px;border-radius:5px;margin:20px 0}\n');
    fprintf(fid, '</style></head><body>\n');
    fprintf(fid, '<h1>Port Data Type Report: %s</h1>\n', modelName);
    if dryRun, fprintf(fid, '<p style="color:#FF9800;font-weight:bold">⚠ DRY RUN — no changes applied</p>\n'); end
    fprintf(fid, '<div class="summary">\n');
    fprintf(fid, '<p><strong>Total:</strong> %d</p>\n', result.totalInports + result.totalOutports);
    fprintf(fid, '<p><strong>Changed:</strong> %d</p>\n', result.changedCount);
    fprintf(fid, '<p><strong>Skipped:</strong> %d</p>\n', numel(result.skipped));
    fprintf(fid, '<p><strong>Errors:</strong> %d</p>\n', numel(result.errors));
    fprintf(fid, '</div>\n');
    % Changed table
    if ~isempty(result.changed)
        fprintf(fid, '<h2>Changed Ports</h2><table><tr><th>Port</th><th>Type</th><th>Old Type</th><th>New Type</th></tr>\n');
        for i = 1:numel(result.changed)
            c = result.changed{i};
            fprintf(fid, '<tr class="changed"><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n', ...
                c.name, c.portType, c.oldType, c.newType);
        end
        fprintf(fid, '</table>\n');
    end
    % Skipped table
    if ~isempty(result.skipped)
        fprintf(fid, '<h2>Skipped</h2><table><tr><th>Port</th><th>Reason</th></tr>\n');
        for i = 1:min(50, numel(result.skipped))
            s = result.skipped{i};
            fprintf(fid, '<tr class="skipped"><td>%s</td><td>%s</td></tr>\n', s.name, s.reason);
        end
        fprintf(fid, '</table>\n');
    end
    % Errors table
    if ~isempty(result.errors)
        fprintf(fid, '<h2>Errors</h2><table><tr><th>Path</th><th>Error</th></tr>\n');
        for i = 1:numel(result.errors)
            e = result.errors{i};
            fprintf(fid, '<tr class="err"><td>%s</td><td>%s</td></tr>\n', e.path, e.error);
        end
        fprintf(fid, '</table>\n');
    end
    fprintf(fid, '<hr><p style="color:#999">Generated by autoSetPortDataTypes.m</p>\n');
    fprintf(fid, '</body></html>\n');
    fclose(fid);
end

%% ================== Core Processing ==================

function [changed, skipped, errors] = processPort(blockPath, blockType, prefixMap, dryRun)
    changed = {};
    skipped = {};
    errors = {};
    try
        blockName = get_param(blockPath, 'Name');
        currentType = get_param(blockPath, 'OutDataTypeStr');
        [prefix, simType] = extractDataType(blockName, prefixMap);
        if isempty(prefix)
            skipped{end+1} = struct('path',blockPath,'name',blockName,'reason','no matching prefix');
            return;
        end
        if strcmp(currentType, simType)
            skipped{end+1} = struct('path',blockPath,'name',blockName,'reason',sprintf('already %s',simType));
            return;
        end
        if ~dryRun
            set_param(blockPath, 'OutDataTypeStr', simType);
        end
        changed{end+1} = struct('path',blockPath,'name',blockName,'portType',blockType,...
            'prefix',prefix,'oldType',currentType,'newType',simType);
        if dryRun
            fprintf('      [DRY-RUN] Would change: %s -> %s (from %s)\n',blockName,simType,currentType);
        end
    catch ME
        errors{end+1} = struct('path',blockPath,'error',ME.message);
        fprintf('      Error processing %s: %s\n',blockPath,ME.message);
    end
end

%% ================== Prefix Extraction ==================

function [prefix, simType] = extractDataType(name, prefixMap)
% Extract data type prefix from signal name and map to Simulink type
% Convention: {type}{Description}  e.g. u16VehicleSpeed → uint16
% Also supports: {type}_{Description}  e.g. u16_VehicleSpeed (backward compat)

    prefix = '';
    simType = '';
    prefixKeys = prefixMap.keys;
    % Sort by length descending to match longer prefixes first (s16 before s1)
    [~, idx] = sort(cellfun(@length, prefixKeys), 'descend');
    prefixKeys = prefixKeys(idx);

    for i = 1:numel(prefixKeys)
        p = prefixKeys{i};
        if startsWith(name, p)
            % Verify the prefix is followed by an uppercase letter or underscore
            % (to avoid matching "s1" in "s123abc")
            rest = name(length(p)+1:end);
            if ~isempty(rest) && (isletter(rest(1)) || rest(1) == '_')
                prefix = p;
                simType = prefixMap(p);
                return;
            end
        end
    end
end

%% ================== Mapping ==================

function map = loadPrefixMapping(mappingFile)
% Load prefix → Simulink data type mapping
    if ~isempty(mappingFile) && isfile(mappingFile)
        jsonStr = fileread(mappingFile);
        mapping = jsondecode(jsonStr);
        map = containers.Map();
        fields = fieldnames(mapping);
        for i = 1:numel(fields)
            map(fields{i}) = mapping.(fields{i});
        end
    else
        % Built-in mapping (most common patterns first)
        map = containers.Map();
        map('s64') = 'int64';
        map('u64') = 'uint64';
        map('s32') = 'int32';
        map('u32') = 'uint32';
        map('s16') = 'int16';
        map('u16') = 'uint16';
        map('s8')  = 'int8';
        map('u8')  = 'uint8';
        map('f64') = 'double';
        map('f32') = 'single';
        map('f16') = 'half';
        map('bool') = 'boolean';
        map('b')   = 'boolean';
        map('enum') = 'Enum: auto';
    end
end

function printMapping(map)
% Print the active mapping table
    fprintf('Active prefix → data type mapping:\n');
    fprintf('  Signal:      {prefix}{Name}       e.g. u16VehicleSpeed → uint16\n');
    fprintf('  Calibration: cal_{prefix}{Name}    e.g. cal_u16Threshold → uint16\n\n');
    keys = sort(map.keys);
    for i = 1:numel(keys)
        fprintf('  %-6s → %-10s  e.g. %sName\n', keys{i}, map(keys{i}), keys{i});
    end
end
