%Program: Epileptiform Event Detector 
%Corresponding Author: Michael Chang (michael.chang@uhnresearch.ca) 
%Copyright (c) 2018, Valiante Lab
%Version FrequencyAnalysis V1.0 

% For quick start: i) Run the script, ii) click OK, iii) select the 
% .abf file to analyze; for demo select "13226009(exampleFile).abf" 

%Description: Standard stage 1 to detect epileptiform events. The script
%can process a single file that you select or a collection of files from a
%directory that you have provided. Additionally, this script will save the
%work space as a .mat file which contains the time points of the seizure
%onset and offset and classificaitons, as well as details regarding how the
%files were detected. These variables will be saved as a struct (.mat
%file).

%% Stage 1: Detect Epileptiform Events
%clear all (reset)
close all
clear all
clc

%Add all subfolders in working directory to the path.
addpath(genpath(pwd));  

%Manually set File Directory
inputdir = 'C:\Users\Michael\OneDrive - University of Toronto\3) Manuscript III (Nature)\Section 2\2) Hepes-buffered Experiments';

%GUI to set thresholds
%Settings, request for user input on threshold
titleInput = 'Specify Detection Parameters';
prompt1 = 'Epileptiform Spike Threshold: average + (3.9 x Sigma)';
prompt2 = 'Artifact Threshold: average + (70 x Sigma)';
prompt3 = 'Figure: Yes (1) or No (0)';
prompt4 = 'Stimulus channel (enter 0 if none; "size (x,2)" if last channel):';
prompt5 = 'Troubleshooting: plot SLEs(1), IIEs(2), IISs(3), Artifacts (4), Review(5), all(6), None(0):';
prompt6 = 'To analyze multiple files, provide the folder directory (leave blank to select individual files):';
prompt = {prompt1, prompt2, prompt3, prompt4, prompt5, prompt6};
dims = [1 70];
definput = {'4', '70', '0', 'size (x,2)', '0', ''};

opts = 'on';    %allow end user to resize the GUI window
InputGUI = (inputdlg(prompt,titleInput,dims,definput, opts));  %GUI to collect End User Inputs
userInput = str2double(InputGUI(1:5)); %convert inputs into numbers

if (InputGUI(6)=="")
    %Load .abf file (raw data), analyze single file
    [FileName,PathName] = uigetfile ('*.abf','pick .abf file', inputdir);%Choose abf file
    [x,samplingInterval,metadata]=abfload([PathName FileName]); %Load the file name with x holding the channel data(10,000 sampling frequency) -> Convert index to time value by dividing 10k
    [spikes, events, SLE, details, artifactSpikes] = detectionInVitro4AP(FileName, userInput, x, samplingInterval, metadata);
    if whos('x').bytes < 2e9    %if 'x' variable larger than 2 GB have to save as v7.3
        save(sprintf('%s.mat', FileName(1:end-4)))  %Save Workspace 
    else
        save(sprintf('%s.mat', FileName(1:end-4)), '-v7.3', '-nocompression')  %Save Workspace 
    end        

else
    % Analyze all files in folder, multiple files
    PathName = char(InputGUI(6));
    S = dir(fullfile(PathName,'*.abf'));

    for k = 1:numel(S)
        clear IIS SLE_final events fnm FileName x samplingInterval metadata %clear all the previous data analyzed
        fnm = fullfile(PathName,S(k).name);
        FileName = S(k).name;
        [x,samplingInterval,metadata]=abfload(fnm);
        [spikes, events, SLE, details, artifactSpikes] = detectionInVitro4AP(FileName, userInput, x, samplingInterval, metadata);
        if whos('x').bytes < 2e9    %if 'x' variable larger than 2 GB have to save as v7.3
            save(sprintf('%s.mat', FileName(1:end-4)))  %Save Workspace 
        else
            save(sprintf('%s.mat', FileName(1:end-4)), '-v7.3', '-nocompression')  %Save Workspace 
        end         
        %Collect the average intensity ratio for SLEs
        %indexSLE = events(:,7) == 1;
        %intensity{k} = events(indexSLE,18);                   
    end
end

fprintf(1,'\nA summary of the detection results can be found in the current working folder: %s\n', pwd)
fprintf(1,'\nThank you for choosing to use Chang & Valiante (2018) Epileptiform Event Detector.\n')
