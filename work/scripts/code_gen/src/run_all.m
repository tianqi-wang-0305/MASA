function run_all()
    % write the log to *.txt file
    diary('run_all_log.txt');
    cleanupObj = onCleanup(@() diary('off'));

    try
        %% 0) choose folder
        rootFolder = uigetdir(pwd, 'please choose the folder which included doc / mdl / src / tst');
        if rootFolder == 0
            disp('Cancel!!!');
            return;
        end
        fprintf("master catalogue：%s\n", rootFolder);

        mdlFolder = fullfile(rootFolder, 'mdl');
        srcFolder = fullfile(rootFolder, 'src');
        tstFolder = fullfile(rootFolder, 'tst');

        if ~exist(mdlFolder, 'dir'), error('can not find folder of mdl：%s', mdlFolder); end
        if ~exist(srcFolder, 'dir'), mkdir(srcFolder); end
        if ~exist(tstFolder, 'dir'), mkdir(tstFolder); end

        %% 1) set generation folder：only for CodeGenFolder / CacheFolder
        genRoot        = fullfile(rootFolder, '_gen');
        genCodeFolder  = fullfile(genRoot, 'codegen');
        genCacheFolder = fullfile(genRoot, 'cache');
        if ~exist(genCodeFolder,  'dir'), mkdir(genCodeFolder);  end
        if ~exist(genCacheFolder, 'dir'), mkdir(genCacheFolder); end

        % note：Simulink.fileGenControl('set', ...) do not support 'GenFolder'
        Simulink.fileGenControl('set', ...
            'CodeGenFolder', genCodeFolder, ...
            'CacheFolder',   genCacheFolder, ...
            'createDir',     true);


        % change working folder to root folder
        origPWD = pwd;
        cd(rootFolder);
        c = onCleanup(@() cd(origPWD)); %#ok<NASGU

        %% 2) collect model
        mdlFiles = [dir(fullfile(mdlFolder, '*.slx')); dir(fullfile(mdlFolder, '*.mdl'))];
        if isempty(mdlFiles)
            error('can not find the model file in mdl folder *.slx / *.mdl');
        end

        %% 3) model handling
        for k = 1:numel(mdlFiles)
            modelPath = fullfile(mdlFiles(k).folder, mdlFiles(k).name);
            [~, modelName] = fileparts(modelPath);
            fprintf("\n========== start model handling：%s ==========\n", modelName);

            load_system(modelPath);

            % --- set swc name as env variable ---
            setenv('SWC_NAME', modelName);
            fprintf('setenv SWC_NAME=%s\n', getenv('SWC_NAME'));
            % --- end setenv ---

            % 3.1 Model Advisor
            try
                runModelAdvisorChecks;
                fprintf("[OK] Model Advisor checking successfully：%s\n", modelName);
            catch ME
                warning("[WARN] Model Advisor checking failure：%s\n%s", modelName, ME.message);
            end

            % 3.2 code generation
            try
                slbuild(modelName);
                fprintf("[OK] code generation successfully：%s\n", modelName);
            catch ME
                warning("[WARN] code generation failure：%s\n%s", modelName, ME.message);
            end

            % 3.3 A2L generation
            try
                coder.asap2.export(modelName, ...
                    'SupportStructureElements', false, ...
                    'IncludeAutosarRteElements', false);
                fprintf("[OK] A2L generation successfully.\n");
            catch ME
                warning("[WARN] A2L generation failure：%s\n%s", modelName, ME.message);
            end

            close_system(modelName, 0);
        end

        %% 4) merge to src / tst
        fprintf("\n========== output arrange ==========\n");

        % 4.1 Model Advisor
        cd(genCacheFolder);
        mdladv_summary_source = ['slprj' filesep 'modeladvisor' filesep];
        mdladv_detail_source = ['slprj' filesep 'modeladvisor' filesep modelName filesep];
        mdladv_destination_source = [rootFolder filesep 'tst' filesep];

        if exist(mdladv_summary_source, 'dir')
            movefile([mdladv_summary_source '*.html'],mdladv_destination_source,'f');
        end
        html = dir(fullfile(mdladv_detail_source, '*.c'));
        if ~isempty(html)
            movefile([mdladv_detail_source '*.html'],mdladv_destination_source,'f');
        end

        fprintf("[OK] model advisor report move to：%s\n", tstFolder);

        % 4.2 collect all C/H/A2L/ARXML to src
        cd(genCodeFolder)
        lib_source = ['slprj' filesep 'autosar' filesep '_sharedutils' filesep];
        source = [modelName '_autosar_rtw' filesep];
        stub_source = [modelName '_autosar_rtw' filesep 'stub' filesep];
        destination_source = [rootFolder filesep 'src' filesep];

        if ~exist(lib_source, 'dir')
            warning('lib_source directory does not exist: %s. Skipping.', lib_source);
        else
            c_file = dir(fullfile(lib_source, '*.c'));
            h_file = dir(fullfile(lib_source, '*.h'));
            if isempty(c_file)
                warning('c file does not exist in lib_source directory: %s. Skipping.', lib_source);
            else
                movefile([lib_source, '*.c'],destination_source,'f');
            end
            
            if isempty(h_file)
                warning('h file does not exist in lib_source directory: %s. Skipping.', lib_source);
            else
                movefile([lib_source, '*.h'],destination_source,'f');
            end
        end

        movefile([source, '*.c'],destination_source,'f');
        movefile([source, '*.h'],destination_source,'f');
        movefile([source, '*.a2l'],destination_source,'f');
        movefile([source, '*.arxml'],destination_source,'f');

        movefile([stub_source, '*.h'],destination_source,'f');

        fprintf("[OK] C/H/A2L/ARXML move to：%s\n", srcFolder);

        %% 5) clear generated folder
        fprintf("\n========== clear generated folder ==========\n");
        % clear _gen（CodeGenFolder/CacheFolder
        cd(rootFolder)
        if exist([rootFolder filesep '_gen'], 'dir')
            rmdir('_gen', 's');
        end
        if exist([rootFolder filesep 'm2m_' modelName], 'dir')
            rmdir(['m2m_' modelName], 's');
        end
        if exist([rootFolder filesep 'sldv_output'], 'dir')
            rmdir('sldv_output', 's');
        end
        if exist([rootFolder filesep 'slprj'], 'dir')
            rmdir('slprj','s');
        end

        % clear mdl generated folder
        cd(mdlFolder)
        if exist([mdlFolder filesep 'm2m_' modelName], 'dir')
            rmdir(['m2m_' modelName], 's');
        end
        if exist([mdlFolder filesep 'sldv_output'], 'dir')
            rmdir('sldv_output', 's');
        end
        if exist([mdlFolder filesep 'slprj'], 'dir')
            rmdir('slprj','s');
        end

        fprintf("\n===== all finished！please check src and tst folder. =====\n");

    catch ME
        fprintf(2, "error：\n%s\n", ME.getReport('extended','hyperlinks','off'));
    end
end
