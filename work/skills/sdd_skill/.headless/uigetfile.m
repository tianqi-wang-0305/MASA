function [fileName, filePath] = uigetfile(varargin)
modelPath = string(getenv("SDD_MODEL_PATH"));
excelPath = string(getenv("SDD_EXCEL_PATH"));

dialogTitle = "";
for k = 1:numel(varargin)
    arg = varargin{k};
    if isstring(arg) || ischar(arg)
        textValue = lower(string(arg));
        if contains(textValue, "simulink model") || contains(textValue, "excel") || contains(textValue, "dependency")
            dialogTitle = textValue;
        end
    end
end

if contains(dialogTitle, "simulink model")
    [filePath, fileName, ext] = fileparts(modelPath);
    fileName = char(fileName + ext);
    filePath = char(filePath + filesep);
elseif contains(dialogTitle, "excel")
    [filePath, fileName, ext] = fileparts(excelPath);
    fileName = char(fileName + ext);
    filePath = char(filePath + filesep);
else
    fileName = 0;
    filePath = 0;
end
end
