results = checkcode('D:\00_Project\55_autoModeling\autoModeling\work\skills\sdd_skill\DdGeneration_ASPICE.m', '-id');
for k = 1:numel(results)
    disp(results(k).message);
    disp(results(k).line);
end
