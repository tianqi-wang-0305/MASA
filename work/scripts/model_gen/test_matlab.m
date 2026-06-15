% Test MATLAB basic functionality
fprintf('Starting MATLAB test...\n');
fprintf('1. License check...\n');
try
    lic = license('test', 'Simulink');
    fprintf('   Simulink license: %d\n', lic);
catch ME
    fprintf('   License error: %s\n', ME.message);
end

fprintf('2. Creating model...\n');
try
    new_system('test_model');
    fprintf('   new_system OK\n');
catch ME
    fprintf('   new_system error: %s\n', ME.message);
end

fprintf('3. Adding blocks...\n');
try
    add_block('simulink/Sources/In1', 'test_model/In1');
    fprintf('   add_block OK\n');
catch ME
    fprintf('   add_block error: %s\n', ME.message);
end

fprintf('4. Saving...\n');
try
    save_system('test_model', 'test_model.slx');
    fprintf('   save OK\n');
catch ME
    fprintf('   save error: %s\n', ME.message);
end

fprintf('Test complete\n');
exit;
