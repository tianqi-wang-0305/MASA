function cs = ModelConfigCommon_v08()
% MATLAB function for configuration set generated on 03-Apr-2026 15:07:57
% MATLAB version: 24.2.0.2712019 (R2024b)

cs = Simulink.ConfigSet;

% Original configuration set version: 24.1.0
if cs.versionCompare('24.1.0') < 0
    error('Simulink:MFileVersionViolation', 'The version of the target configuration set is older than the original configuration set.');
end

% Character encoding: UTF-8

% Do not change the order of the following commands. There are dependencies between the parameters.
cs.set_param('Name', 'Configuration'); % Name
cs.set_param('Description', ''); % Description

% Original configuration set target is autosar.tlc
try
    cs.switchTarget('autosar.tlc', '');
catch ME
    disp(ME.message);
    disp('Setting ''System target file'' to ''ert.tlc''.');
    cs.switchTarget('ert.tlc', '');
end

cs.set_param('HardwareBoard', 'None');   % Hardware board

cs.set_param('TargetLang', 'C');   % Language

cs.set_param('CodeInterfacePackaging', 'Nonreusable function');   % Code interface packaging

cs.set_param('GenerateAllocFcn', 'off');   % Use dynamic memory allocation for model initialization

cs.set_param('Solver', 'FixedStepDiscrete');   % Solver

% Solver
cs.set_param('StartTime', '0.0');   % Start time
cs.set_param('StopTime', '10.0');   % Stop time
cs.set_param('SolverName', 'FixedStepDiscrete');   % Solver
cs.set_param('SolverType', 'Fixed-step');   % Type
cs.set_param('SampleTimeConstraint', 'Unconstrained');   % Periodic sample time constraint
cs.set_param('FixedStep', '0.001');   % Fixed-step size (fundamental sample time)
cs.set_param('EnableFixedStepZeroCrossing', 'off');   % Enable zero-crossing detection for fixed-step simulation
cs.set_param('ConcurrentTasks', 'off');   % Allow tasks to execute concurrently on target
cs.set_param('EnableMultiTasking', 'on');   % Treat each discrete rate as a separate task
cs.set_param('AllowMultiTaskInputOutput', 'off');   % Allow multiple tasks to access inputs and outputs
cs.set_param('PositivePriorityOrder', 'off');   % Higher priority value indicates higher task priority
cs.set_param('AutoInsertRateTranBlk', 'off');   % Automatically handle rate transition for data transfer

% Data Import/Export
cs.set_param('Decimation', '1');   % Decimation
cs.set_param('LoadExternalInput', 'off');   % Load external input
cs.set_param('SaveFinalState', 'off');   % Save final state
cs.set_param('LoadInitialState', 'off');   % Load initial state
cs.set_param('LimitDataPoints', 'on');   % Limit data points
cs.set_param('MaxDataPoints', '1000');   % Maximum number of data points
cs.set_param('SaveFormat', 'StructureWithTime');   % Format
cs.set_param('SaveOutput', 'on');   % Save output
cs.set_param('SaveState', 'off');   % Save states
cs.set_param('SignalLogging', 'on');   % Signal logging
cs.set_param('DSMLogging', 'on');   % Data stores
cs.set_param('StreamToWks', 'on');   % Stream To Workspace blocks
cs.set_param('InspectSignalLogs', 'off');   % Record logged workspace data in Simulation Data Inspector
cs.set_param('SaveTime', 'on');   % Save time
cs.set_param('ReturnWorkspaceOutputs', 'off');   % Single simulation output
cs.set_param('TimeSaveName', 'tout');   % Time variable
cs.set_param('OutputSaveName', 'yout');   % Output variable
cs.set_param('SignalLoggingName', 'logsout');   % Signal logging name
cs.set_param('DSMLoggingName', 'dsmout');   % Data stores logging name
cs.set_param('LoggingToFile', 'off');   % Log Dataset data to file
cs.set_param('DatasetSignalFormat', 'timeseries');   % Dataset signal format

% Optimization
cs.set_param('BlockReduction', 'off');   % Block reduction
cs.set_param('BooleanDataType', 'on');   % Implement logic signals as Boolean data (vs. double)
cs.set_param('ConditionallyExecuteInputs', 'on');   % Conditional input branch execution
cs.set_param('DefaultParameterBehavior', 'Inlined');   % Default parameter behavior
cs.set_param('UseDivisionForNetSlopeComputation', 'UseDivisionForReciprocalsOfIntegersOnly');   % Use division for fixed-point net slope computation
cs.set_param('GainParamInheritBuiltInType', 'off');   % Gain parameters inherit a built-in integer type that is lossless
cs.set_param('UseFloatMulNetSlope', 'off');   % Use floating-point multiplication to handle net slope corrections
cs.set_param('InheritOutputTypeSmallerThanSingle', 'off');   % Inherit floating-point output type smaller than single precision
cs.set_param('DefaultUnderspecifiedDataType', 'single');   % Default for underspecified data type
cs.set_param('UseSpecifiedMinMax', 'off');   % Optimize using the specified minimum and maximum values
cs.set_param('InlineInvariantSignals', 'off');   % Inline invariant signals
cs.set_param('DataBitsets', 'off');   % Use bitsets for storing Boolean data
cs.set_param('StateBitsets', 'off');   % Use bitsets for storing state configuration
cs.set_param('LocalBlockOutputs', 'on');   % Enable local block outputs
cs.set_param('EnableMemcpy', 'off');   % Use memcpy for vector assignment
cs.set_param('OptimizeBlockIOStorage', 'on');   % Signal storage reuse
cs.set_param('ExpressionFolding', 'on');   % Eliminate superfluous local variables (expression folding)
cs.set_param('BufferReuse', 'on');   % Reuse local block outputs
cs.set_param('ReuseModelBlockBuffer', 'on');   % Reuse output buffers of Model blocks
cs.set_param('GlobalBufferReuse', 'on');   % Reuse global block outputs
cs.set_param('GlobalVariableUsage', 'Minimize global data access');   % Optimize global data access
cs.set_param('StrengthReduction', 'on');   % Simplify array indexing
cs.set_param('AdvancedOptControl', '');   % Disable incompatible optimizations
cs.set_param('BooleansAsBitfields', 'off');   % Pack Boolean data into bitfields
cs.set_param('OptimizeBlockOrder', 'off');   % Optimize block operation order in generated code
cs.set_param('BusAssignmentInplaceUpdate', 'on');   % Perform in-place updates for Assignment and Bus Assignment blocks
cs.set_param('DifferentSizesBufferReuse', 'on');   % Reuse buffers of different sizes and dimensions
cs.set_param('OptimizationCustomize', 'on');   % Specify custom optimizations
cs.set_param('MultiThreadedLoops', 'off');   % Generate parallel for-loops
cs.set_param('BitwiseOrLogicalOp', 'Same as modeled');   % Operator to represent Bitwise and Logical Operator blocks
cs.set_param('PassReuseOutputArgsAs', 'Individual arguments');   % Pass reusable subsystem outputs as
cs.set_param('PassReuseOutputArgsThreshold', 12);   % Maximum number of arguments for subsystem outputs
cs.set_param('RollThreshold', 5);   % Loop unrolling threshold
cs.set_param('ActiveStateOutputEnumStorageType', 'Native Integer');   % Base storage type for automatically created enumerations
cs.set_param('ZeroExternalMemoryAtStartup', 'off');   % Remove root level I/O zero initialization
cs.set_param('ZeroInternalMemoryAtStartup', 'off');   % Remove internal data zero initialization
cs.set_param('InitFltsAndDblsToZero', 'off');   % Use memset to initialize floats and doubles to 0.0
cs.set_param('NoFixptDivByZeroProtection', 'off');   % Remove code that protects against division arithmetic exceptions
cs.set_param('EfficientFloat2IntCast', 'on');   % Remove code from floating-point to integer conversions that wraps out-of-range values
cs.set_param('EfficientMapNaN2IntZero', 'on');   % Remove code from floating-point to integer conversions with saturation that maps NaN to zero
cs.set_param('LifeSpan', 'auto');   % Application lifespan (days)
cs.set_param('ClockResolution', '-1');   % Clock resolution (seconds, -1 for inherited)
cs.set_param('MaxStackSize', '100');   % Maximum stack size (bytes)
cs.set_param('BufferReusableBoundary', 'on');   % Buffer for reusable subsystems
cs.set_param('RemoveLocalVariableInitialization', 'on');   % Remove local variable initialization to zero value
cs.set_param('SimCompilerOptimization', 'on');   % Compiler optimization level
cs.set_param('AccelVerboseBuild', 'off');   % Verbose accelerator builds
cs.set_param('UseRowMajorAlgorithm', 'off');   % Use algorithms optimized for row-major array layout
cs.set_param('LabelGuidedReuse', 'off');   % Use signal labels to guide buffer reuse
cs.set_param('DenormalBehavior', 'GradualUnderflow');   % In accelerated simulation modes, denormal numbers can be flushed to zero using 'flush-to-zero' option.
cs.set_param('EfficientTunableParamExpr', 'on');   % Remove code from tunable parameter expressions that saturates out-of-range values

% Diagnostics
cs.set_param('RTPrefix', 'error');   % "rt" prefix for identifiers
cs.set_param('ConsistencyChecking', 'none');   % Solver data inconsistency
cs.set_param('ArrayBoundsChecking', 'none');   % Array bounds exceeded
cs.set_param('SignalInfNanChecking', 'error');   % Inf or NaN block output
cs.set_param('StringTruncationChecking', 'error');   % String truncation checking
cs.set_param('SignalRangeChecking', 'error');   % Simulation range checking
cs.set_param('ReadBeforeWriteMsg', 'EnableAllAsError');   % Detect read before write
cs.set_param('WriteAfterWriteMsg', 'EnableAllAsError');   % Detect write after write
cs.set_param('WriteAfterReadMsg', 'EnableAllAsError');   % Detect write after read
cs.set_param('AlgebraicLoopMsg', 'error');   % Algebraic loop
cs.set_param('ArtificialAlgebraicLoopMsg', 'error');   % Minimize artificial algebraic loop occurrences
cs.set_param('SaveWithDisabledLinksMsg', 'warning');   % Block diagram contains disabled library links
cs.set_param('SaveWithParameterizedLinksMsg', 'error');   % Block diagram contains parameterized library links
cs.set_param('UnderspecifiedInitializationDetection', 'Simplified');   % Underspecified initialization detection
cs.set_param('MergeDetectMultiDrivingBlocksExec', 'error');   % Detect multiple driving blocks executing at the same time step
cs.set_param('SignalResolutionControl', 'UseLocalSettings');   % Signal resolution
cs.set_param('BlockPriorityViolationMsg', 'error');   % Block priority violation
cs.set_param('TimeAdjustmentMsg', 'none');   % Sample hit time adjusting
cs.set_param('SolverPrmCheckMsg', 'error');   % Automatic solver parameter selection
cs.set_param('InheritedTsInSrcMsg', 'error');   % Source block specifies -1 sample time
cs.set_param('MultiTaskDSMMsg', 'error');   % Multitask data store
cs.set_param('MultiTaskCondExecSysMsg', 'error');   % Multitask conditionally executed subsystem
cs.set_param('MultiTaskRateTransMsg', 'error');   % Multitask data transfer
cs.set_param('SingleTaskRateTransMsg', 'none');   % Single task data transfer
cs.set_param('TasksWithSamePriorityMsg', 'warning');   % Tasks with equal priority
cs.set_param('SigSpecEnsureSampleTimeMsg', 'error');   % Enforce sample times specified by Signal Specification blocks
cs.set_param('CheckMatrixSingularityMsg', 'error');   % Division by singular matrix
cs.set_param('IntegerOverflowMsg', 'error');   % Wrap on overflow
cs.set_param('Int32ToFloatConvMsg', 'warning');   % 32-bit integer to single precision float conversion
cs.set_param('ParameterDowncastMsg', 'error');   % Detect downcast
cs.set_param('ParameterOverflowMsg', 'error');   % Detect overflow
cs.set_param('ParameterUnderflowMsg', 'error');   % Detect underflow
cs.set_param('ParameterPrecisionLossMsg', 'warning');   % Detect precision loss
cs.set_param('ParamSuppressDoubleToSinglePrecisionLossMsg', 'off');   % Suppress double to single detection
cs.set_param('ParamPrecisionLossAbsoluteDiffThreshold', '0.0');   % Absolute difference threshold
cs.set_param('ParamPrecisionLossRelativeDiffThreshold', '0.0');   % Relative difference threshold
cs.set_param('ParamOverflowErrorThreshold', 'OneBit');   % Bits of error threshold
cs.set_param('ParameterTunabilityLossMsg', 'error');   % Detect loss of tunability
cs.set_param('FixptConstUnderflowMsg', 'none');   % Detect underflow
cs.set_param('FixptConstOverflowMsg', 'none');   % Detect overflow
cs.set_param('FixptConstPrecisionLossMsg', 'none');   % Detect precision loss
cs.set_param('UnderSpecifiedDataTypeMsg', 'warning');   % Underspecified data types
cs.set_param('UnnecessaryDatatypeConvMsg', 'warning');   % Unnecessary type conversions
cs.set_param('VectorMatrixConversionMsg', 'error');   % Vector/matrix block input conversion
cs.set_param('FcnCallInpInsideContextMsg', 'error');   % Context-dependent inputs
cs.set_param('SignalLabelMismatchMsg', 'warning');   % Signal label mismatch
cs.set_param('UnconnectedInputMsg', 'error');   % Unconnected block input ports
cs.set_param('UnconnectedOutputMsg', 'error');   % Unconnected block output ports
cs.set_param('UnconnectedLineMsg', 'error');   % Unconnected line
cs.set_param('SFcnCompatibilityMsg', 'error');   % S-function upgrades needed
cs.set_param('FrameProcessingCompatibilityMsg', 'error');   % Block behavior depends on frame status of signal
cs.set_param('UniqueDataStoreMsg', 'error');   % Duplicate data store names
cs.set_param('BusObjectLabelMismatch', 'error');   % Element name mismatch
cs.set_param('RootOutportRequireBusObject', 'error');   % Unspecified bus object at root Outport block
cs.set_param('AssertControl', 'DisableAll');   % Model Verification block enabling
cs.set_param('AllowSymbolicDim', 'off');   % Allow symbolic dimension specification
cs.set_param('ModelReferenceVersionMismatchMessage', 'none');   % Model block version mismatch
cs.set_param('ModelReferenceIOMismatchMessage', 'error');   % Port and parameter mismatch
cs.set_param('UnknownTsInhSupMsg', 'error');   % Unspecified inheritability of sample time
cs.set_param('ModelReferenceDataLoggingMessage', 'error');   % Unsupported data logging
cs.set_param('ModelReferenceNoExplicitFinalValueMsg', 'none');   % No explicit final value for model arguments
cs.set_param('ModelReferenceSymbolNameMessage', 'warning');   % Insufficient maximum identifier length
cs.set_param('StateNameClashWarn', 'warning');   % State name clash
cs.set_param('OperatingPointInterfaceChecksumMismatchMsg', 'warning');   % Operating point restore interface checksum mismatch
cs.set_param('NonCurrentReleaseOperatingPointMsg', 'error');   % Operating point object from a different release
cs.set_param('PregeneratedLibrarySubsystemCodeDiagnostic', 'warning');   % Behavior when pregenerated library subsystem code is missing
cs.set_param('SubsystemReferenceDiagnosticForUnitTest', 'error');   % Behavior when a matching unit test for subsystem reference is missing
cs.set_param('InitInArrayFormatMsg', 'warning');   % Initial state is array
cs.set_param('StrictBusMsg', 'ErrorOnBusTreatedAsVector');   % Bus signal treated as vector
cs.set_param('BusNameAdapt', 'WarnAndRepair');   % Repair bus selections
cs.set_param('NonBusSignalsTreatedAsBus', 'none');   % Non-bus signals treated as bus signals
cs.set_param('SFUnusedDataAndEventsDiag', 'warning');   % Unused data, events, messages and functions
cs.set_param('SFUnexpectedBacktrackingDiag', 'warning');   % Unexpected backtracking
cs.set_param('SFInvalidInputDataAccessInChartInitDiag', 'warning');   % Invalid input data access in chart initialization
cs.set_param('SFNoUnconditionalDefaultTransitionDiag', 'warning');   % No unconditional default transitions
cs.set_param('SFTransitionOutsideNaturalParentDiag', 'warning');   % Transition outside natural parent
cs.set_param('SFUnreachableExecutionPathDiag', 'warning');   % Unreachable execution path
cs.set_param('SFUndirectedBroadcastEventsDiag', 'warning');   % Undirected event broadcasts
cs.set_param('SFTransitionActionBeforeConditionDiag', 'warning');   % Transition action specified before condition action
cs.set_param('SFOutputUsedAsStateInMooreChartDiag', 'error');   % Read-before-write to output in Moore chart
cs.set_param('SFTemporalDelaySmallerThanSampleTimeDiag', 'warning');   % Absolute time temporal value shorter than sampling period
cs.set_param('SFSelfTransitionDiag', 'warning');   % Self-transition on leaf state
cs.set_param('SFExecutionAtInitializationDiag', 'warning');   % 'Execute-at-initialization' disabled in presence of input events
cs.set_param('IntegerSaturationMsg', 'warning');   % Saturate on overflow
cs.set_param('AllowedUnitSystems', 'all');   % Allowed unit systems
cs.set_param('UnitsInconsistencyMsg', 'warning');   % Units inconsistency messages
cs.set_param('AllowAutomaticUnitConversions', 'on');   % Allow automatic unit conversions
cs.set_param('RCSCRenamedMsg', 'warning');   % Detect non-reused custom storage classes
cs.set_param('RCSCObservableMsg', 'warning');   % Detect ambiguous custom storage class final values
cs.set_param('ForceCombineOutputUpdateInSim', 'off');   % Combine output and update methods for code generation and simulation
cs.set_param('UnderSpecifiedDimensionMsg', 'none');   % Underspecified dimensions
cs.set_param('DebugExecutionForFMUViaOutOfProcess', 'off');   % FMU Import blocks
cs.set_param('ArithmeticOperatorsInVariantConditions', 'error');   % Arithmetic operations in variant conditions
cs.set_param('VariantConditionMismatch', 'error');   % Variant condition mismatch at signal source and destination
cs.set_param('InheritVATfromSVC', 'warning');   % Variant activation time inherited from Simulink.VariantControl
cs.set_param('VariantConfigNotUsedByTopModel', 'warning');   % Variant configuration not used by top model
cs.set_param('ParamWriterValidationControl', 'UseLocalSettings');   % Parameter Writer block validation

% Hardware Implementation
cs.set_param('ProdHWDeviceType', 'Intel->x86-64 (Windows64)');   % Production device vendor and type
cs.set_param('ProdLongLongMode', 'off');   % Support long long
cs.set_param('ProdEqTarget', 'on');   % Test hardware is the same as production hardware
cs.set_param('TargetPreprocMaxBitsSint', 32);   % Maximum bits for signed integer in C preprocessor
cs.set_param('TargetPreprocMaxBitsUint', 32);   % Maximum bits for unsigned integer in C preprocessor
cs.set_param('HardwareBoardFeatureSet', 'EmbeddedCoderHSP');   % Feature set for selected hardware board

% Model Referencing
cs.set_param('UpdateModelReferenceTargets', 'IfOutOfDateOrStructuralChange');   % Rebuild
cs.set_param('EnableRefExpFcnMdlSchedulingChecks', 'on');   % Enable strict scheduling checks for referenced models
cs.set_param('EnableParallelModelReferenceBuilds', 'off');   % Enable parallel model reference builds
cs.set_param('ParallelModelReferenceErrorOnInvalidPool', 'on');   % Perform consistency check on parallel pool
cs.set_param('ModelReferenceNumInstancesAllowed', 'Single');   % Total number of instances allowed per top model
cs.set_param('PropagateVarSize', 'Infer from blocks in model');   % Propagate sizes of variable-size signals
cs.set_param('ModelDependencies', '');   % Model dependencies
cs.set_param('ModelReferencePassRootInputsByReference', 'on');   % Pass fixed-size scalar root inputs by value for code generation
cs.set_param('ModelReferenceMinAlgLoopOccurrences', 'off');   % Minimize artificial algebraic loop occurrences
cs.set_param('PropagateSignalLabelsOutOfModel', 'off');   % Propagate all signal labels out of the model
cs.set_param('SupportModelReferenceSimTargetCustomCode', 'off');   % Include custom code for referenced models
cs.set_param('UseModelRefSolver', 'off');   % Use local solver when referencing model

% Simulation Target
cs.set_param('SimCustomSourceCode', '');   % Additional code
cs.set_param('SimUserSources', '');   % Source files
cs.set_param('SimCustomHeaderCode', '');   % Include headers
cs.set_param('SimCustomInitializer', '');   % Initialize code
cs.set_param('SimCustomTerminator', '');   % Terminate code
cs.set_param('SimReservedNameArray', []);   % Reserved names
cs.set_param('SimUserIncludeDirs', '');   % Include directories
cs.set_param('SimUserLibraries', '');   % Libraries
cs.set_param('SimUserDefines', '');   % Defines
cs.set_param('SimCustomCompilerFlags', '');   % Compiler flags
cs.set_param('SimCustomLinkerFlags', '');   % Linker flags
cs.set_param('SFSimEnableDebug', 'off');   % Allow setting breakpoints during simulation
cs.set_param('SFSimEcho', 'on');   % Echo expressions without semicolons
cs.set_param('SimCtrlC', 'on');   % Break on Ctrl-C
cs.set_param('SimIntegrity', 'on');   % Enable memory integrity checks
cs.set_param('SimParseCustomCode', 'off');   % Import custom code
cs.set_param('SimGenImportedTypeDefs', 'on');   % Generate typedefs for imported bus and enumeration types
cs.set_param('CompileTimeRecursionLimit', 50);   % Compile-time recursion limit for MATLAB functions
cs.set_param('EnableRuntimeRecursion', 'on');   % Enable run-time recursion for MATLAB functions
cs.set_param('EnableImplicitExpansion', 'on');   % Enable implicit expansion in MATLAB functions
cs.set_param('MATLABDynamicMemAlloc', 'off');   % Dynamic memory allocation in MATLAB functions
cs.set_param('GPUAcceleration', 'off');   % GPU acceleration
cs.set_param('UsePrecompiledLibraries', 'Prefer');   % Use precompiled libraries for MATLAB functions
cs.set_param('LegacyBehaviorForPersistentVarInContinuousTime', 'off');   % Enable continuous-time MATLAB functions to write to initialized persistent variables
cs.set_param('SimHardwareAcceleration', 'generic');   % Hardware acceleration
cs.set_param('SimTargetLang', 'C');   % Language

% Code Generation
cs.set_param('CodeReplacementLibrary', 'None');   % Code replacement library
cs.set_param('ArrayLayout', 'Column-major');   % Array layout
cs.set_param('ExistingSharedCode', '');   % Existing shared code
cs.set_param('EmbeddedCoderDictionary', '');   % Shared coder dictionary
cs.set_param('TLCOptions', '');   % TLC command line options
cs.set_param('Toolchain', 'Automatically locate an installed toolchain');   % Toolchain
cs.set_param('GenCodeOnly', 'on');   % Generate code only
cs.set_param('PackageGeneratedCodeAndArtifacts', 'off');   % Package code and artifacts
cs.set_param('PostCodeGenCommand', 'post_codegen_insert_include(''*_CalParameter.h'',''Rte_CtSFLC.h'')');   % Post code generation command
cs.set_param('GenerateReport', 'on');   % Create code generation report
cs.set_param('RTWVerbose', 'on');   % Verbose build
cs.set_param('RetainRTWFile', 'off');   % Retain .rtw file
cs.set_param('ProfileTLC', 'off');   % Profile TLC
cs.set_param('TLCDebug', 'off');   % Start TLC debugger when generating code
cs.set_param('TLCCoverage', 'off');   % Start TLC coverage when generating code
cs.set_param('TLCAssert', 'off');   % Enable TLC assertion
cs.set_param('BuiltinFFTWCallback', 'off');   % Built-in FFTW library callback
cs.set_param('RTWUseSimCustomCode', 'off');   % Use the same custom code settings as Simulation Target
cs.set_param('CustomSourceCode', '');   % Additional code
cs.set_param('CustomHeaderCode', '');   % Include headers
cs.set_param('CustomInclude', '');   % Include directories
cs.set_param('CustomSource', '');   % Source files
cs.set_param('CustomLibrary', '');   % Libraries
cs.set_param('CustomDefine', '');   % Defines
cs.set_param('CustomBLASCallback', '');   % Custom BLAS library callback
cs.set_param('CustomLAPACKCallback', '');   % Custom LAPACK library callback
cs.set_param('CustomFFTCallback', '');   % Custom FFT library callback
cs.set_param('CustomInitializer', '');   % Initialize code
cs.set_param('CustomTerminator', '');   % Terminate code
cs.set_param('BuildConfiguration', 'Faster Runs');   % Build configuration
cs.set_param('IncludeHyperlinkInReport', 'off');   % Code-to-model
cs.set_param('LaunchReport', 'off');   % Open report automatically
cs.set_param('PortableWordSizes', 'off');   % Enable portable word sizes
cs.set_param('CreateSILPILBlock', 'None');   % Create block
cs.set_param('CodeExecutionProfiling', 'off');   % Measure task execution time
cs.set_param('CodeProfilingInstrumentation', 'off');   % Measure function execution times
cs.set_param('CodeStackProfiling', 'off');   % Measure task stack usage
cs.set_param('CodeCoverageSettings', coder.coverage.CodeCoverageSettings([],'off','off','None'));   % Third-party tool
cs.set_param('SILPILDebugging', 'off');   % Enable source-level debugging for SIL or PIL
cs.set_param('RemoveFixptWordSizeChecks', 'off');   % Suppress generation of fixed-point word size checks
cs.set_param('DataTypeReplacement', 'CDataTypesFixedWidth');   % Data type replacement
cs.set_param('CoderTypedefsCompatibility', 'off');   % Coder typedefs compatibility
cs.set_param('GenerateTraceInfo', 'off');   % Model-to-code
cs.set_param('GenerateTraceReport', 'off');   % Eliminated / virtual blocks
cs.set_param('GenerateTraceReportSl', 'off');   % Traceable Simulink blocks
cs.set_param('GenerateTraceReportSf', 'off');   % Traceable Stateflow objects
cs.set_param('GenerateTraceReportEml', 'off');   % Traceable MATLAB functions
cs.set_param('GenerateWebview', 'off');   % Generate model Web view
cs.set_param('GenerateCodeMetricsReport', 'on');   % Generate static code metrics
cs.set_param('GenerateCodeReplacementReport', 'off');   % Summarize which blocks triggered code replacements
cs.set_param('ObjectivePriorities', {'MISRA C:2012 guidelines'});   % Prioritized objectives
cs.set_param('CheckMdlBeforeBuild', 'Off');   % Check model before generating code
cs.set_param('DLLearnablesCompression', 'None');   % Learnables compression
cs.set_param('GenerateComments', 'on');   % Include comments
cs.set_param('ForceParamTrailComments', 'on');   % Verbose comments for 'Model default' storage class
cs.set_param('CommentStyle', 'Auto');   % Comment style
cs.set_param('IgnoreCustomStorageClasses', 'off');   % Ignore custom storage classes
cs.set_param('IgnoreTestpoints', 'on');   % Ignore test point signals
cs.set_param('MaxIdLength', 31);   % Maximum identifier length
cs.set_param('ShowEliminatedStatement', 'on');   % Show eliminated blocks
cs.set_param('OperatorAnnotations', 'off');   % Operator annotations
cs.set_param('SimulinkDataObjDesc', 'off');   % Simulink data object descriptions
cs.set_param('SFDataObjDesc', 'off');   % Stateflow object descriptions
cs.set_param('MATLABFcnDesc', 'off');   % MATLAB user comments
cs.set_param('MangleLength', 4);   % Minimum mangle length
cs.set_param('SharedChecksumLength', 8);   % Shared checksum length
cs.set_param('CustomSymbolStrGlobalVar', '$R$N$M');   % Global variables
cs.set_param('CustomSymbolStrType', '$N$R$M_T');   % Global types
cs.set_param('CustomSymbolStrField', '$N$M');   % Field name of global types
cs.set_param('CustomSymbolStrFcn', '$R$N$M$F');   % Subsystem methods
cs.set_param('CustomSymbolStrFcnArg', 'rt$I$N$M');   % Subsystem method arguments
cs.set_param('CustomSymbolStrBlkIO', 'rtb_$N$M');   % Local block output variables
cs.set_param('CustomSymbolStrTmpVar', '$N$M');   % Local temporary variables
cs.set_param('CustomSymbolStrMacro', '$R$N$M');   % Constant macros
cs.set_param('CustomSymbolStrUtil', '$N$C');   % Shared utilities identifier format
cs.set_param('CustomSymbolStrEmxType', 'emxArray_$M$N');   % EMX array types identifier format
cs.set_param('CustomSymbolStrEmxFcn', 'emx$M$N');   % EMX array utility functions identifier format
cs.set_param('CustomUserTokenString', '');   % Custom token text
cs.set_param('EnableCustomComments', 'off');   % Custom comments (MPT objects only)
cs.set_param('DefineNamingRule', 'UpperCase');   % #define naming
cs.set_param('ParamNamingRule', 'None');   % Parameter naming
cs.set_param('SignalNamingRule', 'None');   % Signal naming
cs.set_param('InsertBlockDesc', 'on');   % Simulink block descriptions
cs.set_param('AnnotationsInComments', 'off');   % Connected annotations in block comments
cs.set_param('InsertPolySpaceComments', 'off');   % Insert Polyspace comments
cs.set_param('SimulinkBlockComments', 'on');   % Simulink block comments
cs.set_param('StateflowObjectComments', 'on');   % Stateflow object comments
cs.set_param('BlockCommentType', 'BlockPathComment');   % Trace to model using
cs.set_param('MATLABSourceComments', 'off');   % MATLAB source code as comments
cs.set_param('InternalIdentifier', 'Shortened');   % System-generated identifiers
cs.set_param('InlinedPrmAccess', 'Literals');   % Generate scalar inlined parameters as
cs.set_param('ReqsInCode', 'on');   % Requirements in block comments
cs.set_param('UseSimReservedNames', 'off');   % Use the same reserved names as Simulation Target
cs.set_param('ReservedNameArray', []);   % Reserved names
cs.set_param('EnumMemberNameClash', 'error');   % Duplicate enumeration member names
cs.set_param('TargetLibSuffix', '');   % Suffix applied to target library name
cs.set_param('TargetPreCompLibLocation', '');   % Precompiled library location
cs.set_param('TargetLangStandard', 'C99 (ISO)');   % Language standard
cs.set_param('UtilityFuncGeneration', 'Shared location');   % Shared code placement
cs.set_param('MultiwordTypeDef', 'System defined');   % Multiword type definitions
cs.set_param('DynamicStringBufferSize', 256);   % Buffer size of dynamically-sized string (bytes)
cs.set_param('GenerateFullHeader', 'on');   % Generate full file banner
cs.set_param('InferredTypesCompatibility', 'off');   % Create preprocessor directive in rtwtypes.h
cs.set_param('GenerateSampleERTMain', 'off');   % Generate an example main program
cs.set_param('IncludeMdlTerminateFcn', 'off');   % Terminate function required
cs.set_param('GRTInterface', 'off');   % Classic call interface
cs.set_param('CombineOutputUpdateFcns', 'on');   % Single output/update function
cs.set_param('CombineSignalStateStructs', 'off');   % Combine signal/state structures
cs.set_param('MatFileLogging', 'off');   % MAT-file logging
cs.set_param('SuppressErrorStatus', 'on');   % Remove error status field in real-time model data structure
cs.set_param('IncludeFileDelimiter', 'Auto');   % #include file delimiter
cs.set_param('ERTCustomFileBanners', 'on');   % Enable custom file banner
cs.set_param('SupportAbsoluteTime', 'on');   % Support absolute time
cs.set_param('PurelyIntegerCode', 'off');   % Support floating-point numbers
cs.set_param('SupportNonFinite', 'off');   % Support non-finite numbers
cs.set_param('SupportComplex', 'off');   % Support complex numbers
cs.set_param('SupportContinuousTime', 'off');   % Support continuous time
cs.set_param('SupportNonInlinedSFcns', 'off');   % Support non-inlined S-functions
cs.set_param('RemoveDisableFunc', 'off');   % Remove disable function
cs.set_param('RemoveResetFunc', 'on');   % Remove reset function
cs.set_param('SupportVariableSizeSignals', 'off');   % Support variable-size signals
cs.set_param('ParenthesesLevel', 'Maximum');   % Parentheses level
cs.set_param('CastingMode', 'Explicit');   % Casting modes
cs.set_param('GenerateSharedConstants', 'off');   % Generate shared constants
cs.set_param('ERTHeaderFileRootName', '$R$E');   % Header files
cs.set_param('ERTSourceFileRootName', '$R$E');   % Source files
cs.set_param('ERTFilePackagingFormat', 'Compact');   % File packaging format
cs.set_param('InstructionSetExtensions', {'None'});   % Leverage target hardware instruction set extensions
cs.set_param('HeaderGuardPrefix', '');   % Header guard prefix
cs.set_param('ExtMode', 'off');   % External mode
cs.set_param('ExtModeTransport', 0);   % Transport layer
cs.set_param('ExtModeMexFile', 'ext_comm');   % MEX-file name
cs.set_param('ExtModeStaticAlloc', 'off');   % Static memory allocation
cs.set_param('GlobalDataDefinition', 'Auto');   % Data definition
cs.set_param('GlobalDataReference', 'Auto');   % Data declaration
cs.set_param('EnableUserReplacementTypes', 'off');   % Specify custom data type names
cs.set_param('DSAsUniqueAccess', 'off');   % Implement each data store block as a unique access point
cs.set_param('ExtModeTesting', 'off');   % External mode testing
cs.set_param('ExtModeMexArgs', '');   % MEX-file arguments
cs.set_param('ExtModeIntrfLevel', 'Level1');   % External mode interface level
cs.set_param('RTWCAPISignals', 'off');   % Generate C API for signals
cs.set_param('RTWCAPIParams', 'off');   % Generate C API for parameters
cs.set_param('RTWCAPIStates', 'off');   % Generate C API for states
cs.set_param('RTWCAPIRootIO', 'off');   % Generate C API for root-level I/O
cs.set_param('ERTSrcFileBannerTemplate', 'ert_code_template.cgt');   % Source file template
cs.set_param('ERTHdrFileBannerTemplate', 'ert_code_template.cgt');   % Header file template
cs.set_param('ERTDataSrcFileTemplate', 'ert_code_template.cgt');   % Source file template
cs.set_param('ERTDataHdrFileTemplate', 'ert_code_template.cgt');   % Header file template
cs.set_param('ERTCustomFileTemplate', 'example_file_process.tlc');   % File customization template
cs.set_param('EnableDataOwnership', 'off');   % Use owner from data object for data definition placement
cs.set_param('SignalDisplayLevel', 10);   % Signal display level
cs.set_param('ParamTuneLevel', 10);   % Parameter tune level
cs.set_param('PreserveExpressionOrder', 'on');   % Preserve operand order in expression
cs.set_param('PreserveIfCondition', 'on');   % Preserve condition expression in if statement
cs.set_param('ConvertIfToSwitch', 'off');   % Convert if-elseif-else patterns to switch-case statements
cs.set_param('PreserveExternInFcnDecls', 'on');   % Preserve extern keyword in function declarations
cs.set_param('PreserveStaticInFcnDecls', 'on');   % Preserve static keyword in function declarations
cs.set_param('SuppressUnreachableDefaultCases', 'off');   % Suppress generation of default cases for switch statements if unreachable
cs.set_param('EnableSignedLeftShifts', 'off');   % Replace multiplications by powers of two with signed bitwise shifts
cs.set_param('EnableSignedRightShifts', 'off');   % Allow right shifts on signed integers
cs.set_param('IndentStyle', 'K&R');   % Indent style
cs.set_param('IndentSize', '2');   % Indent size
cs.set_param('NewlineStyle', 'Default');   % Newline style
cs.set_param('MaxLineWidth', 80);   % Maximum line width
cs.set_param('ReplacementTypes', struct('double','','single','','int32','','int16','','int8','','uint32','','uint16','','uint8','','boolean','','int','','uint','','char','','uint64','','int64',''));   % Data type names
cs.set_param('MaxIdInt64', '');   % 64-bit integer maximum identifier
cs.set_param('MinIdInt64', '');   % 64-bit integer minimum identifier
cs.set_param('MaxIdUint64', '');   % 64-bit unsigned integer maximum identifier
cs.set_param('MaxIdInt32', '');   % 32-bit integer maximum identifier
cs.set_param('MinIdInt32', '');   % 32-bit integer minimum identifier
cs.set_param('MaxIdUint32', '');   % 32-bit unsigned integer maximum identifier
cs.set_param('MaxIdInt16', '');   % 16-bit integer maximum identifier
cs.set_param('MinIdInt16', '');   % 16-bit integer minimum identifier
cs.set_param('MaxIdUint16', '');   % 16-bit unsigned integer maximum identifier
cs.set_param('MaxIdInt8', '');   % 8-bit integer maximum identifier
cs.set_param('MinIdInt8', '');   % 8-bit integer minimum identifier
cs.set_param('MaxIdUint8', '');   % 8-bit unsigned integer maximum identifier
cs.set_param('BooleanTrueId', 'TRUE');   % Boolean true identifier
cs.set_param('BooleanFalseId', 'FALSE');   % Boolean false identifier
cs.set_param('TypeLimitIdReplacementHeaderFile', '');   % Type limit identifier replacement header file
cs.set_param('AutosarCompilerAbstraction', 'on');   % Use AUTOSAR compiler abstraction macros
cs.set_param('AutosarMatrixIOAsArray', 'off');   % Support root-level matrix I/O using one-dimensional arrays
cs.set_param('AutosarMaxShortNameLength', 128);   % Maximum SHORT-NAME length
cs.set_param('AutosarSchemaVersion', 'R22-11');   % Generate XML file for schema version

% Simulink Coverage
cs.set_param('CovEnable', 'off');   % Enable coverage analysis
cs.set_param('RecordCoverage', 'off');   % Record coverage for this model
cs.set_param('CovModelRefEnable', 'off');   % Record coverage for referenced models

% HDL Coder
try 
	cs_componentCC = hdlcoderconfigsetup(cs);

catch ME
	warning('Simulink:ConfigSet:AttachComponentError', '%s', ME.message);
end

% Design Verifier
try
  cs_componentCC = Sldv.ConfigComp;
  cs.attachComponent(cs_componentCC);
  cs.set_param('DVMode', 'TestGeneration');   % Mode
  cs.set_param('DVMaxProcessTime', 300);   % Maximum analysis time (s)
  cs.set_param('DVUseParallel', 'off');   % Validate test cases or counterexamples with parallel computing
  cs.set_param('DVDesignMinMaxConstraints', 'on');   % Use specified input minimum and maximum values
  cs.set_param('DVOutputDir', 'sldv_output/$ModelName$');   % Output folder
  cs.set_param('DVMakeOutputFilesUnique', 'on');   % Make output file names unique by adding a suffix
  cs.set_param('DVBlockReplacement', 'off');   % Apply block replacements
  cs.set_param('DVParameterConfiguration', 'None');   % Parameter configuration
  cs.set_param('DVTestgenTarget', 'Model');   % Test generation target
  cs.set_param('DVModelCoverageObjectives', 'ConditionDecision');   % Model coverage objectives
  cs.set_param('DVTestConditions', 'UseLocalSettings');   % Test conditions
  cs.set_param('DVTestObjectives', 'UseLocalSettings');   % Test objectives
  cs.set_param('DVMaxTestCaseSteps', 10000);   % Maximum test case steps
  cs.set_param('DVTestSuiteOptimization', 'Auto');   % Test suite optimization
  cs.set_param('DVAssertions', 'UseLocalSettings');   % Assertion blocks
  cs.set_param('DVProofAssumptions', 'UseLocalSettings');   % Proof assumptions
  cs.set_param('DVExtendExistingTests', 'off');   % Extend using existing test data
  cs.set_param('DVIgnoreExistTestSatisfied', 'on');   % Separate objectives satisfied with the existing tests/coverage data in the report
  cs.set_param('DVIgnoreCovSatisfied', 'off');   % Extend using existing coverage data
  cs.set_param('DVCovFilter', 'off');   % Ignore objectives based on filter
  cs.set_param('DVIncludeRelationalBoundary', 'off');   % Include relational boundary objectives
  cs.set_param('DVDefectChecker', 'on');   % Defect checker
  cs.set_param('DVProvingStrategy', 'Prove');   % Strategy
  cs.set_param('DVDataFileName', '$ModelName$_sldvdata');   % Data file name
  cs.set_param('DVSaveExpectedOutput', 'off');   % Include expected output values
  cs.set_param('DVRandomizeNoEffectData', 'off');   % Randomize data that do not affect the outcome
  cs.set_param('DVSaveHarnessModel', 'off');   % Generate separate harness model after analysis
  cs.set_param('DVModelReferenceHarness', 'on');   % Reference input model in generated harness
  cs.set_param('DVSaveReport', 'off');   % Generate report of the results
  cs.set_param('DVSFcnSupport', 'on');   % Support S-Functions in the analysis
  cs.set_param('DVCodeAnalysisExtraOptions', '');   % Additional options for code analysis
  cs.set_param('DVCodeAnalysisIgnoreVolatile', 'on');   % Ignore the volatile qualifier
  cs.set_param('DVReduceRationalApprox', 'on');   % Run additional analysis to reduce instances of rational approximation
  cs.set_param('DVSlTestFileName', '$ModelName$_test');   % Test File name
  cs.set_param('DVSlTestHarnessName', '$ModelName$_sldvharness');   % Test Harness name
  cs.set_param('DVRebuildModelRepresentation', 'IfChangeIsDetected');   % Rebuild model representation
  cs.set_param('DVAnalyzeAllStartupVariants', 'on');   % Analyze all Startup Variants
catch ME
  warning('Simulink:ConfigSet:AttachComponentError', '%s', ME.message);
end