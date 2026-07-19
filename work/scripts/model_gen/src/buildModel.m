function modelName = buildModel(spec, saveDir)
% buildModel  Build a Simulink model from a specification using model_edit
%   Creates models by calling the Simulink Agentic Toolkit's model_edit function,
%   which uses the same MCP infrastructure as /buildModel.
%
%   Inputs:
%       spec     - Struct (or JSON file path) with:
%           .modelName     - Model name (default: 'Untitled')
%           .solver        - Solver config struct
%           .inputs        - Array of {name, dataType}
%           .outputs       - Array of {name, dataType}
%           .subsystems    - Array of {name, description, blocks?, connections?}
%           .constants     - Array of {name, value, dataType}
%           .connections   - Cell array of 'src -> dst' strings
%       saveDir  - Output directory (default: current dir)
%
%   Usage:
%       % Struct inline
%       spec = struct('modelName','MyCtrl');
%       spec.inputs = struct('name',{'In1','In2'}, 'dataType',{'single','boolean'});
%       spec.outputs = struct('name','Out1', 'dataType','single');
%       buildModel(spec);
%
%       % From JSON file
%       buildModel('path/to/spec.json');

    fprintf('=== Build Model (model_edit) ===\n\n');

    %% Parse input
    if nargin < 2; saveDir = pwd; end

    if ischar(spec) || isstring(spec)
        specStr = fileread(char(spec));
        spec = jsondecode(specStr);
        fprintf('Loaded spec: %s\n', spec);
    end

    fld = @(s, n, d) getField(s, n, d);
    modelName = fld(spec, 'modelName', 'Untitled');
    inputs  = ensureStructArray(fld(spec, 'inputs', struct('name',{},'dataType',{})));
    outputs = ensureStructArray(fld(spec, 'outputs', struct('name',{},'dataType',{})));
    subsystems = ensureStructArray(fld(spec, 'subsystems', struct('name',{},'description',{})));
    constants  = ensureStructArray(fld(spec, 'constants', struct('name',{},'value',{},'dataType',{})));
    connections = fld(spec, 'connections', {});

    %% Ensure toolkit on path
    tk = getToolkitRoot();
    if isempty(tk)
        error('Simulink Agentic Toolkit not found. Set SATK_ROOT or run from project root.');
    end
    addpath(fullfile(tk, 'tools'));

    %% Phase 1: Create and configure model
    fprintf('[1/5] Creating model: %s\n', modelName);
    new_system(modelName);
    set_param(modelName, 'Solver', fld(spec, 'solver.type', 'FixedStepDiscrete'));
    set_param(modelName, 'FixedStep', fld(spec, 'solver.fixedStep', '0.01'));
    set_param(modelName, 'StopTime', fld(spec, 'solver.stopTime', '100'));

    %% Phase 2: Add ports via model_edit
    fprintf('[2/5] Adding %d inputs, %d outputs...\n', numel(inputs), numel(outputs));
    ops = {};
    for i = 1:numel(inputs)
        ops{end+1} = struct('op','add_block','type','Inport', ...
            'name', inputs(i).name, 'ref', sprintf('in%d',i)); %#ok<AGROW>
    end
    for i = 1:numel(outputs)
        ops{end+1} = struct('op','add_block','type','Outport', ...
            'name', outputs(i).name, 'ref', sprintf('out%d',i)); %#ok<AGROW>
    end
    r = model_edit(modelName, 'root', jsonencode(ops), 'layout_mode', 'incremental');

    % Configure data types
    for i = 1:numel(inputs)
        try set_param([modelName '/' inputs(i).name], 'OutDataTypeStr', inputs(i).dataType); catch; end
    end
    for i = 1:numel(outputs)
        try set_param([modelName '/' outputs(i).name], 'OutDataTypeStr', outputs(i).dataType); catch; end
    end

    %% Phase 3: Add subsystems (wrapper + internal)
    fprintf('[3/5] Adding %d subsystems...\n', numel(subsystems));

    % Create wrapper subsystem
    ops = {};
    ops{1} = struct('op','create_subsystem','name','MainSubsystem','ref','wrapper');
    for i = 1:numel(subsystems)
        ops{end+1} = struct('op','create_subsystem','name',subsystems(i).name, ...
            'ref', sprintf('ss%d',i)); %#ok<AGROW>
    end
    model_edit(modelName, 'root', jsonencode(ops), 'layout_mode', 'incremental');

    % Set descriptions
    for i = 1:numel(subsystems)
        if isfield(subsystems(i),'description') && ~isempty(subsystems(i).description)
            try set_param([modelName '/MainSubsystem/' subsystems(i).name], ...
                'Description', subsystems(i).description); catch; end
        end
    end

    % Add constants at root level
    for i = 1:numel(constants)
        blk = [modelName '/' constants(i).name];
        add_block('built-in/Constant', blk);
        set_param(blk, 'Value', num2str(constants(i).value));
        if isfield(constants(i),'dataType') && ~isempty(constants(i).dataType)
            set_param(blk, 'OutDataTypeStr', constants(i).dataType);
        end
    end

    %% Phase 4: Connect top level
    fprintf('[4/5] Wiring...\n');
    totalConns = numel(connections) + numel(inputs) + numel(outputs);
    connIdx = 0;
    for i = 1:numel(connections)
        conn = strtrim(string(connections{i}));
        parts = split(conn, '->');
        if numel(parts) == 2
            src = strtrim(parts{1}); dst = strtrim(parts{2});
            try
                srcParts = split(src, '/');
                dstParts = split(dst, '/');
                if numel(srcParts) == 1
                    add_line(modelName, [src '/1'], [dst '/1'], 'autorouting','on');
                else
                    add_line(modelName, char(src), char(dst), 'autorouting','on');
                end
                connIdx = connIdx + 1;
            catch ME
                fprintf('  ⚠ Connection failed: %s (%s)\n', conn, ME.message);
            end
        end
    end
    fprintf('  Connected %d / %d\n', connIdx, numel(connections));

    %% Phase 5: Layout and save
    fprintf('[5/5] Saving...\n');
    try Simulink.BlockDiagram.arrangeSystem(modelName); catch; end
    saveFile = fullfile(saveDir, [modelName '.slx']);
    save_system(modelName, saveFile);
    close_system(modelName);

    fprintf('\n=== Model Created ===\n');
    fprintf('Name: %s\n', modelName);
    fprintf('File: %s\n', saveFile);
    fprintf('Inputs: %d, Outputs: %d, Subsystems: %d\n', ...
        numel(inputs), numel(outputs), numel(subsystems));

    %% Generate HTML build report
    reportFile = fullfile(saveDir, [modelName '_build_report.html']);
    fid = fopen(reportFile, 'w');
    fprintf(fid, '<!DOCTYPE html>\n<html><head><meta charset="UTF-8">\n');
    fprintf(fid, '<title>Build Report - %s</title>\n', modelName);
    fprintf(fid, '<style>body{font-family:-apple-system,sans-serif;margin:40px}');
    fprintf(fid, 'h1{color:#333;border-bottom:2px solid #4CAF50;padding-bottom:10px}');
    fprintf(fid, '.card{background:#f9f9f9;border-radius:8px;padding:20px;margin:15px 0}');
    fprintf(fid, 'table{border-collapse:collapse;width:100%%}');
    fprintf(fid, 'th,td{border:1px solid #ddd;padding:10px;text-align:left}');
    fprintf(fid, 'th{background:#4CAF50;color:white}');
    fprintf(fid, '</style></head><body>\n');
    fprintf(fid, '<h1>Model Build Report: %s</h1>\n', modelName);
    fprintf(fid, '<div class="card">\n');
    fprintf(fid, '<p><strong>File:</strong> %s</p>\n', saveFile);
    fprintf(fid, '<p><strong>Inputs:</strong> %d</p>\n', numel(inputs));
    fprintf(fid, '<p><strong>Outputs:</strong> %d</p>\n', numel(outputs));
    fprintf(fid, '<p><strong>Subsystems:</strong> %d</p>\n', numel(subsystems));
    fprintf(fid, '</div>\n');
    % Inputs table
    if ~isempty(inputs)
        fprintf(fid, '<h2>Inputs</h2><table><tr><th>Name</th><th>Data Type</th></tr>\n');
        for i = 1:numel(inputs)
            dt = ''; if isfield(inputs(i),'dataType'), dt = inputs(i).dataType; end
            fprintf(fid, '<tr><td>%s</td><td>%s</td></tr>\n', inputs(i).name, dt);
        end
        fprintf(fid, '</table>\n');
    end
    % Outputs table
    if ~isempty(outputs)
        fprintf(fid, '<h2>Outputs</h2><table><tr><th>Name</th><th>Data Type</th></tr>\n');
        for i = 1:numel(outputs)
            dt = ''; if isfield(outputs(i),'dataType'), dt = outputs(i).dataType; end
            fprintf(fid, '<tr><td>%s</td><td>%s</td></tr>\n', outputs(i).name, dt);
        end
        fprintf(fid, '</table>\n');
    end
    fprintf(fid, '<hr><p style="color:#999">Generated by buildModel.m</p>\n');
    fprintf(fid, '</body></html>\n');
    fclose(fid);
    fprintf('Report: %s\n', reportFile);
end

%% ================== Utilities ==================

function arr = ensureStructArray(s)
    if isempty(s); arr = struct('name',{},'dataType',{}); return; end
    if ~isfield(s, 'dataType'); [s.dataType] = deal('single'); end
    arr = s;
end

function val = getField(s, name, default)
    val = default;
    parts = strsplit(name, '.');
    c = s;
    try
        for i = 1:numel(parts); c = c.(parts{i}); end
        if ~isempty(c); val = c; end
    catch; end
end

function rootPath = getToolkitRoot()
    envPath = string(getenv('SATK_ROOT'));
    if strlength(envPath) > 0 && exist(envPath, 'dir')
        rootPath = char(envPath); return;
    end
    scriptPath = fileparts(mfilename('fullpath'));
    candidates = {
        fullfile(scriptPath, '..', '..', '..', 'simulink-agentic-toolkit');
        fullfile(scriptPath, '..', '..', '..', '..', 'simulink-agentic-toolkit');
    };
    for i = 1:numel(candidates)
        d = fullfile(candidates{i}, 'tools', 'model_edit', 'model_edit.p');
        if exist(d, 'file'); rootPath = candidates{i}; return; end
    end
    rootPath = '';
end
