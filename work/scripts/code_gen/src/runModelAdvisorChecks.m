% Create Model Advisor Checks
CheckIDList = {
   
    'mathworks.design.UnconnectedLinesPorts',...            % UnconnectedLinesPorts
    'mathworks.metricchecks.CyclomaticComplexity',...       % CyclomaticComplexity
    'mathworks.design.DiagnosticSFcn',...                   % Check array bounds and solver consistency checking if S-Functions exist
    'mathworks.design.DiagnosticDataStoreBlk',...           % Verify that read/write order diagnostic checking is on if there are Data Store blocks
    'mathworks.design.DataStoreMemoryBlkIssue',...          % Checks for modeling issues related to Data Store Memory blocks
    'mathworks.design.SLXModelProperties',...               % Check Model History properties
    'mathworks.design.SFuncAnalyzer',...                    % Perform S-function Checks
    'mathworks.design.OptimizationSettings',...             % Having unselected optimizations can lead to non-optimal results
    'mathworks.codegen.LUTRangeCheckCode',...               % Identify lookup table blocks that generate expensive out-of-range checking code
    'mathworks.codegen.CodeInstrumentation',...             % Identify questionable code instrumentation (data I/O)
    'mathworks.codegen.LogicBlockUseNonBooleanOutput',...   % Identify logic blocks that are outputting non-Boolean data types
    'mathworks.codegen.EfficientTunableParamExpr',...       % Identify configuration parameters that might lead to the generation of inefficient saturation code
    'mathworks.codegen.EnableLongLong',...                  % Check for usage of 'long long' data type when expensive multi-word types are detected
    'mathworks.misra.CodeGenSettings',...                   % Identify configuration parameters that might impact MISRA C:2012 compliant code generation
    'mathworks.misra.BlkSupport',...                        % Identify blocks that are not recommended for MISRA C:2012 compliant code generation.
    'mathworks.misra.BlockNames',...                        % Identify block names containing "/".
    'mathworks.misra.AssignmentBlocks',...                  % Identify Assignment blocks that do not have the simulation run-time diagnostic Action
    'mathworks.misra.SwitchDefault',...                     % Identify switch case expressions that do not have a default case
    'mathworks.misra.AutosarReceiverInterface',...          % Identify AUTOSAR receiver interface ports that do not have a matching error port
    'mathworks.misra.CompliantCGIRConstructions',...        % Identify bitwise operations on signed integers
    'mathworks.misra.RecursionCompliance',...               % Identify function calls that are recursive
    'mathworks.misra.CompareFloatEquality',...              % Identify equality and inequality operations on floating-point values
    'mathworks.misra.DefaultChoiceVariantsCheck',...        % Identify variant blocks with startup variant activation time that do not have a default choice
    'mathworks.jmaab.jc_0243',...                           % Identify long subsystem names
    'mathworks.jmaab.jc_0247',...                           % Identify long block names
    'mathworks.jmaab.jc_0244',...                           % Identify Inports and Outports with long names
    'mathworks.jmaab.jc_0246',...                           % Identify long parameter names
    'mathworks.jmaab.jc_0700',...                           % Checks if the model parameter 'Unused data, events, messages and functions' is not set to 'none'
    'mathworks.jmaab.jc_0642',...                           % Identifies blocks with block parameter 'Integer Rounding Mode' set to 'Simplest' when the configuration parameter 'Signed integer division rounds to' is set to 'Undefined'
    'mathworks.jmaab.jc_0641',...                           % Check if sample time property of a block is set to -1 (inherited)
    'mathworks.jmaab.jc_0659',...                           % There must not be any block between a Conditional Subsystem block and a Merge block
    'mathworks.maab.na_0003',...                            % Identify usage of simple logical expressions in If block
    'mathworks.jmaab.jc_0656',...                           % Identify Switch Case blocks and If blocks without default/else conditions
    'mathworks.jmaab_v6.jc_0651',...                        % Identify operation blocks that directly specify the 'Output data type' parameter when changing the data type of the block output signal
    'mathworks.jmaab.jc_0794',...                           % Identify division operations in Simulink resulting in divide-by-zero error
    'mathworks.jmaab_v6.na_0020',...                        % Check for number of inputs/outputs to a Variant Subsystem
    'mathworks.jmaab.jc_0797',...                           % Identify dangling transitions and unconnected Stateflow States and Junctions in Stateflow Charts
    'mathworks.jmaab.db_0137',...                           % Identify states which are the only substate within a state with OR(exclusive) type decomposition
    'mathworks.jmaab.jc_0531',...                           % Identify all groupings of states that do not have a default transition or do not have the default state as the top-most state
    'mathworks.jmaab.jc_0723',...                           % Identify transitions ending on external child states
    'mathworks.jmaab.jc_0773',...                           % Identify unconditional transitions in flow charts
    'mathworks.maab.db_0143',...                            % Identify levels in the model that include basic blocks and subsystems
    'mathworks.sldv.deadlogic',...                          % Identify logic that stays inactive during execution
    'mathworks.hism.hisl_0101',...                          % Identify blocks or operations that result in unreachable or dead code
    'mathworks.hism.hisl_0074',...                          % Check diagnostic settings in the model configuration that apply to variants and might impact safety
    'mathworks.hism.hisl_0078',...                          % Identify identical modeling patterns that can increase the complexity of model and generated code
    'mathworks.hism.hisf_0013',...                          % Identify transition paths that cross parallel state boundaries in Stateflow charts
    'mathworks.hism.hisl_0061',...                          % Identify local data identifiers that are defined in multiple scopes within a chart
    
};

Array = ModelAdvisor.run({gcs},CheckIDList);
disp(Array);
disp(CheckIDList);

ModelAdvisor.summaryReport(Array);