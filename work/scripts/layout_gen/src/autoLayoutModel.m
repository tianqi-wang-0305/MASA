function result = autoLayoutModel(modelName, varargin)
% autoLayoutModel  Auto-layout a Simulink model for clean presentation
%   Recursively arranges all subsystems with left-to-right signal flow,
%   aligns ports, and optimizes line routing.
%
%   Inputs:
%       modelName  - Model name or path (.slx)
%       varargin   - 'Scope' - subsystem path (default: root)
%                    'Style' - 'hierarchical' (default) | 'compact'
%                    'AlignPorts' - true/false (default: true)
%
%   Usage:
%       autoLayoutModel('Model.slx');
%       autoLayoutModel('Model.slx', 'Scope', 'Model/Subsystem');

    fprintf('=== Auto Layout Model ===\n\n');
    result = struct('status', 'ok', 'scopesProcessed', 0, 'errors', {});

    %% Parse inputs
    p = inputParser;
    addRequired(p, 'modelName', @(x) ischar(x) || isstring(x));
    addParameter(p, 'Scope', '', @ischar);
    addParameter(p, 'Style', 'hierarchical', @(x) any(validatestring(x, {'hierarchical', 'compact'})));
    addParameter(p, 'AlignPorts', true, @islogical);
    parse(p, modelName, varargin{:});

    modelName = char(p.Results.modelName);
    scope = p.Results.Scope;
    style = p.Results.Style;
    alignPorts = p.Results.AlignPorts;

    %% Load model
    [~, modelBase, ~] = fileparts(modelName);
    if isempty(modelBase)
        modelBase = modelName;
    end

    try
        load_system(modelBase);
    catch
        load_system(modelName);
    end

    if ~bdIsLoaded(modelBase)
        error('Cannot load model: %s', modelBase);
    end

    %% Collect scopes to layout
    if isempty(scope)
        scopes = {modelBase};
    else
        scopes = {scope};
    end

    % Add all subsystems if hierarchical
    if strcmp(style, 'hierarchical')
        subSystems = find_system(modelBase, 'LookUnderMasks', 'all', ...
            'BlockType', 'SubSystem');
        for i = 1:numel(subSystems)
            if ~any(strcmp(subSystems{i}, scopes))
                scopes{end+1} = subSystems{i}; %#ok<AGROW>
            end
        end
    end

    %% Process each scope
    for i = 1:numel(scopes)
        sysPath = scopes{i};
        fprintf('  Layout [%d/%d]: %s\n', i, numel(scopes), sysPath);
        try
            layoutSingleScope(sysPath, alignPorts);
            result.scopesProcessed = result.scopesProcessed + 1;
        catch ME
            result.errors{end+1} = struct('scope', sysPath, 'error', ME.message); %#ok<AGROW>
            fprintf('    ⚠ %s\n', ME.message);
        end
    end

    %% Summary
    fprintf('\n=== Layout Complete ===\n');
    fprintf('Scopes processed: %d / %d\n', result.scopesProcessed, numel(scopes));
    if ~isempty(result.errors)
        fprintf('Errors: %d\n', numel(result.errors));
    end
end

function layoutSingleScope(sysPath, alignPorts)
% Layout a single subsystem scope using Simulink auto-arrange
    try
        % Get all blocks in this scope
        allBlocks = find_system(sysPath, 'SearchDepth', 1, 'Type', 'Block');
        blocksInScope = {};
        for i = 1:numel(allBlocks)
            if ~strcmp(allBlocks{i}, sysPath)
                blocksInScope{end+1} = allBlocks{i}; %#ok<AGROW>
            end
        end

        if numel(blocksInScope) < 2
            return; % Nothing meaningful to layout
        end

        % Align ports if requested
        if alignPorts
            alignPortsInScope(sysPath);
        end

        % Use Simulink's built-in auto-arrange
        Simulink.BlockDiagram.arrangeSystem(sysPath);

    catch ME
        % If auto-arrange fails, try a simple manual layout
        try
            manualLayout(sysPath);
        catch
            rethrow(ME);
        end
    end
end

function alignPortsInScope(sysPath)
% Align Inport blocks to left, Outport blocks to right
    inports = find_system(sysPath, 'SearchDepth', 1, 'BlockType', 'Inport');
    outports = find_system(sysPath, 'SearchDepth', 1, 'BlockType', 'Outport');
    subsystems = find_system(sysPath, 'SearchDepth', 1, 'BlockType', 'SubSystem');

    % Get current bounding box of the scope
    try
        pos = get_param(sysPath, 'Position');
    catch
        pos = [0, 0, 1000, 800];
    end
    leftX = pos(1) + 30;
    rightX = pos(3) - 120;
    yStart = pos(2) + 40;
    yStep = 40;

    % Place inports on the left
    yPos = yStart;
    for i = 1:numel(inports)
        if ~strcmp(inports{i}, sysPath)
            set_param(inports{i}, 'Position', [leftX, yPos, leftX+30, yPos+14]);
            yPos = yPos + yStep;
        end
    end

    % Place outports on the right
    yPos = yStart;
    for i = 1:numel(outports)
        if ~strcmp(outports{i}, sysPath)
            set_param(outports{i}, 'Position', [rightX, yPos, rightX+30, yPos+14]);
            yPos = yPos + yStep;
        end
    end

    % Place subsystems in the middle area
    if numel(subsystems) > 0
        midX = leftX + 150;
        yPos = yStart;
        for i = 1:numel(subsystems)
            if ~strcmp(subsystems{i}, sysPath)
                set_param(subsystems{i}, 'Position', [midX, yPos, midX+120, yPos+60]);
                yPos = yPos + 80;
            end
        end
    end
end

function manualLayout(sysPath)
% Fallback manual layout when auto-arrange fails
    blocks = find_system(sysPath, 'SearchDepth', 1, 'Type', 'Block');
    xPos = 50;
    yPos = 50;
    for i = 1:numel(blocks)
        if ~strcmp(blocks{i}, sysPath)
            try
                set_param(blocks{i}, 'Position', [xPos, yPos, xPos+80, yPos+40]);
                yPos = yPos + 60;
                if yPos > 800
                    yPos = 50;
                    xPos = xPos + 150;
                end
            catch
                % Skip blocks that can't be positioned
            end
        end
    end
end
