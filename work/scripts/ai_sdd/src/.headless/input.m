function value = input(promptText, varargin)
modelPath = getenv("SDD_MODEL_PATH");
excelPath = getenv("SDD_EXCEL_PATH");

promptLower = lower(string(promptText));
if contains(promptLower, "simulink model")
    value = char(string(modelPath));
elseif contains(promptLower, "excel")
    value = char(string(excelPath));
else
    value = "";
end
end
