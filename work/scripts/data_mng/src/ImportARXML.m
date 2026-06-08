clear
clc

[fileName, pathName] = uigetfile('*.arxml', 'Please select ARXML file');

object = arxml.importer(fileName);

name = getComponentNames(object);

createComponentAsModel(object, name{1,1}, ...
    'ModelPeriodicRunnablesAs', 'FunctionCallSubsystem');

clearvars object name fileName pathName ans
