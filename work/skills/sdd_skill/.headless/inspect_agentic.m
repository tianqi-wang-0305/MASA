addpath('D:\00_Project\55_autoModeling\autoModeling\work\simulink-agentic-toolkit');
mdl = "D:\00_Project\09\DLCC\mdl\CtDLCC.slx";
ov = model_overview(mdl, "root", "interfaces");
disp(class(ov));
disp(extractBefore(string(ov), 2000));
if isstruct(ov)
    disp(fieldnames(ov));
end
rd = model_read(mdl, "root", "1");
disp(class(rd));
disp(extractBefore(string(rd), 2000));
if isstruct(rd)
    disp(fieldnames(rd));
end
