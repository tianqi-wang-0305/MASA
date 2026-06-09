addpath('D:\00_Project\55_autoModeling\autoModeling\work\simulink-agentic-toolkit');
addpath('D:\00_Project\55_autoModeling\autoModeling\work\skills\sdd_skill');
pdfFile = DdGeneration_ASPICE('D:\00_Project\09\DLCC\mdl\CtDLCC.slx', 'D:\BLDC\MotorControl_FOC\BMP.xlsx');
disp(pdfFile);
