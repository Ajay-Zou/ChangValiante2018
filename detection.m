%Program: Epileptiform Activity Detector 
%Author: Michael Chang (michael.chang@live.ca), Fred Chen and Liam Long; 
%Copyright (c) 2018, Valiante Lab
%Version 3.0

%% Clear All
close all
clear all
clc

%% GUI to set thresholds
%Settings, request for user input on threshold
titleInput = 'Specify Detection Thresholds';
prompt1 = 'Epileptiform Spike Threshold: average + (6 x Sigma)';
prompt2 = 'Artifact Threshold: average + (100 x Sigma) ';
prompt3 = 'Figure: Yes (1) or No (0)'
prompt = {prompt1, prompt2, prompt3};
dims = [1 70];
definput = {'6', '100', '0'};
opts = 'on';
threshold_multiple = str2double(inputdlg(prompt,titleInput,dims,definput, opts));

%setting on distance between spikes, hard coded
distanceSpike = 1;  %distance between spikes (seconds)
distanceArtifact = 0.6; %distance between artifacts (seconds)

%% Load .abf and excel data
    [FileName,PathName] = uigetfile ('*.abf','pick .abf file', 'C:\Users\User\OneDrive - University of Toronto\3) Manuscript III (Nature)\Section 2\Control Data\1) Control (VGAT-ChR2, light-triggered)\1) abf files');%Choose abf file
    [x,samplingInterval,metadata]=abfload([PathName FileName]); %Load the file name with x holding the channel data(10,000 sampling frequency) -> Convert index to time value by dividing 10k
                                                                                         
%% create time vector
frequency = 1000000/samplingInterval; %Hz. si is the sampling interval in microseconds from the metadata
t = (0:(length(x)- 1))/frequency;
t = t';

%% Seperate signals from .abf files
LFP = x(:,1);   %original LFP signal
LED = x(:,2);   %light pulse signal

%% Data Processing 
%Center the LFP data
LFP_normalized = LFP - LFP(1);                                      %centered signal at 0, y-axis

%Lowpass butter filter [2Hz]
fc = 2; % Cut off frequency
[b,a] = butter(2,fc/(frequency/2)); % Butterworth filter of order 2
LFP_normalizedLowPassFiltered = filtfilt(b,a,LFP_normalized); % Will be the filtered signal

%Bandpass butter filter [1 - 100 Hz]
[b,a] = butter(2, [[1 100]/(frequency/2)], 'bandpass');
LFP_normalizedFiltered = filtfilt (b,a,LFP_normalized);             %Filtered signal

%Absolute value of the filtered data
AbsLFP_normalizedFiltered = abs(LFP_normalizedFiltered);            %1st derived signal

%Derivative of the filtered data (absolute value)
DiffLFP_normalizedFiltered = abs(diff(LFP_normalizedFiltered));     %2nd derived signal

%Power of the derivative of the filtered data (absolute values)     
powerFeature = (DiffLFP_normalizedFiltered).^2;                     %3rd derived signal

%Lowpass butter filter [2 Hz], for offset
fc = 2; % Cut off frequency
[b,a] = butter(2,fc/(frequency/2)); %Butterworth filter of order 2
powerFeatureLowPassFiltered = filtfilt(b,a,powerFeature); %filtered signal

%Lowpass butter filter [25 Hz], for onset
fc = 25; % Cut off frequency
[b,a] = butter(2,fc/(frequency/2)); %Butterworth filter of order 2
powerFeatureLowPassFiltered25 = filtfilt(b,a,powerFeature); %filtered signal

%% Find Light pulse
[P] = pulse_seq(LED);

%% Detect potential events (epileptiform/artifacts) | Derivative Values
[epileptiformLocation, artifacts, locs_spike_1st] = detectEvents (DiffLFP_normalizedFiltered, frequency);

%remove potential events
for i = 1:size(epileptiformLocation,1)
AbsLFP_normalizedFiltered (epileptiformLocation (i,1):epileptiformLocation (i,2)) = [-1];
end

%remove artifacts
for i = 1:size(artifacts,1)
AbsLFP_normalizedFiltered (artifacts(i,1):artifacts(i,2)) = [-1];
end

%Isolate baseline recording
AbsLFP_normalizedFiltered (AbsLFP_normalizedFiltered == -1) = [];
AbsLFP_normalizedFilteredBaseline = AbsLFP_normalizedFiltered; %Rename

%Characterize baseline features from absolute value of the filtered data 
avgBaseline = mean(AbsLFP_normalizedFilteredBaseline); %Average
sigmaBaseline = std(AbsLFP_normalizedFilteredBaseline); %Standard Deviation

%% Detect events (epileptiform/artifacts) | Absolute Values

%Recreate the Absolute filtered LFP (1st derived signal) vector
AbsLFP_normalizedFiltered = abs(LFP_normalizedFiltered); %the LFP analyzed

%Define thresholds for detection, using inputs from GUI
minPeakHeight = avgBaseline+(threshold_multiple(1)*sigmaBaseline);      %threshold for epileptiform spike detection
minPeakDistance = distanceSpike*frequency;                              %minimum distance spikes must be apart
minArtifactHeight = avgBaseline+(threshold_multiple(2)*sigmaBaseline);  %threshold for artifact spike detection
minArtifactDistance = distanceArtifact*frequency;                       %minimum distance artifact spikes must be apart

%Detect events
[epileptiformLocation, artifacts, locs_spike_2nd] = detectEvents (AbsLFP_normalizedFiltered, frequency, minPeakHeight, minPeakDistance, minArtifactHeight, minArtifactDistance);

%% Finding event time 
%Onset times (s)
onsetTimes = epileptiformLocation(:,1)/frequency; %frequency is your sampling rate

%Offset Times (s)
offsetTimes = epileptiformLocation(:,2)/frequency; 

%Duration of Epileptiform event 
duration = offsetTimes-onsetTimes;

%putting it all into an matrix 
epileptiformTime = [onsetTimes, offsetTimes, duration];

%% Classifier
SLE = epileptiformTime(epileptiformTime(:,3)>=10,:);
IIS = epileptiformTime(epileptiformTime(:,3)<10,:);

%% SLE: Determine exact onset and offset times | Power Feature
% Scanning Low-Pass Filtered Power signal for more accurate onset/offset times
for i = 1:size(SLE,1)
    
    %Rough SLE onset and offset times,  
    onsetSLE = int64((SLE(i,1)*10000));
    offsetSLE = int64((SLE(i,2))*10000);

    %SLE "context" (pre/post- baseline)
    onsetBaselineStart = (onsetSLE-10000);
    onsetBaselineEnd = (onsetSLE+5000);
    offsetBaselineStart = (offsetSLE-5000);
    offsetBaselineEnd = (offsetSLE+10000);

    %Range of LFP to search
    onsetContext = int64(onsetBaselineStart:onsetBaselineEnd);
    offsetContext = int64(offsetBaselineStart:offsetBaselineEnd); 

    %Locating the onset time
    prominence = max(powerFeatureLowPassFiltered25(onsetContext))/3; %SLE onset where spike prominience > 1/3 the maximum amplitude
    [onset_pks, onset_locs] = findpeaks(powerFeatureLowPassFiltered25(onsetContext), 'MinPeakProminence', prominence);     
    SLEonset_final(i,1) = t(onsetContext(onset_locs(1))); %First spike is the onset   
   
    %Locating the offset time
    %make sure it's not light triggered
    %[Place Holder]
    
    meanOffsetBaseline = mean(powerFeatureLowPassFiltered(offsetContext)); %SLE ends when signal returned to half the mean power of signal
    OffsetLocation = powerFeatureLowPassFiltered(offsetContext) > meanOffsetBaseline/2; 
    indexOffset = find(OffsetLocation, 1, 'last'); %Last point is the offset     
    SLEoffset_final(i,1) = t(offsetContext(indexOffset)); 
    
    
    %Test plot onset
    figure;
    set(gcf,'NumberTitle','off', 'color', 'w'); %don't show the figure number
    set(gcf,'Name', sprintf ('SLE onset #%d', i)); %select the name you want
    set(gcf, 'Position', get(0, 'Screensize'));   
    subplot (2,1,1)
    plot(t(onsetContext),LFP_normalized(onsetContext))
    hold on
    plot(t(onsetSLE), LFP_normalized(onsetSLE), 'x', 'color', 'red', 'MarkerSize', 12)  %initial (rough) detection
    plot(SLEonset_final(i,1), LFP_normalized(onsetContext(onset_locs(1))), 'o', 'color', 'black', 'MarkerSize', 14)   %Detected onset point 
    plot(t(onsetContext(onset_locs)), LFP_normalized(onsetContext(onset_locs)), '*', 'color', 'green', 'MarkerSize', 14)    %Final (Refined) detection
    %Labels
    title ('LFP normalized');
    ylabel ('mV');
    xlabel ('Time (sec)');
    
    subplot (2,1,2)
    plot(t(onsetContext), powerFeatureLowPassFiltered25(onsetContext))
    hold on
    plot(t(onsetSLE), powerFeatureLowPassFiltered25(onsetSLE), 'x', 'color', 'red', 'MarkerSize', 12)     %initial (rough) detection
    plot(SLEonset_final(i,1), powerFeatureLowPassFiltered25(onsetContext(onset_locs(1))), 'o', 'color', 'black', 'MarkerSize', 14)    %Detected onset point 
    plot(t(onsetContext(onset_locs)), powerFeatureLowPassFiltered25(onsetContext(onset_locs)), '*', 'color', 'green', 'MarkerSize', 14)    %Final (Refined) detection
    %Labels
    title ('Power, Low Pass Filtered (2 Hz)');
    ylabel ('mV');
    xlabel ('Time (sec)');
    
end

SLE_final = [SLEonset_final, SLEoffset_final];  %final list of SLEs, need to filter out artifacts

%% Plotting out the detected SLEs | To figure out how off you are
%define variables
data1 = LFP_normalized;
data2 = powerFeature;

for i = 1:size(SLE_final,1)
%     figure;
%     set(gcf,'NumberTitle','off', 'color', 'w'); %don't show the figure number
%     set(gcf,'Name', sprintf ('SLE #%d', i)); %select the name you want
%     set(gcf, 'Position', get(0, 'Screensize'));   
%    
    time1 = single(SLE_final(i,1)*10000);
    time2= single(SLE_final(i,2)*10000);
    rangeSLE = (time1:time2);
    SLE_Vector{i,1} = rangeSLE;   %store the datarange for SLEs

    if time1>50001
        rangeOverview = (time1-50000:time2+50000);
    else
        rangeOverview = (1:time2+50000);
    end
    
    SLE_Vector{i,2} = rangeOverview;   %store the SLE vectors
 
end

    
    subplot (2,1,1)
    %overview
    plot (t(rangeOverview),data1(rangeOverview))
    hold on
    %SLE
    plot (t(rangeSLE),data1(rangeSLE))
    %onset/offset markers
    plot (t(time1), data1(time1), 'o', 'MarkerSize', 12, 'MarkerFaceColor', 'red') %onset
    plot (t(time2), data1(time2), 'o', 'MarkerSize', 12, 'MarkerFaceColor', 'red') %offset
    %Labels
    title ('Derivative of Filtered LFP');
    ylabel ('mV');
    xlabel ('Time (sec)');


    subplot (2,1,2)
    %overview
    plot (t(rangeOverview),data2(rangeOverview))
    hold on
    %SLE
    plot (t(rangeSLE),data2(rangeSLE))
    %onset/offset markers
    plot (t(time1), data2(time1), 'o', 'MarkerSize', 12, 'MarkerFaceColor', 'red') %onset
    plot (t(time2), data2(time2), 'o', 'MarkerSize', 12, 'MarkerFaceColor', 'red') %offset
    %Labels
    title ('Absolute Derivative of Filtered LFP');
    ylabel ('mV');
    xlabel ('Time (sec)');
end



%% Identify light-triggered Events

% %Find light-triggered spikes 
% triggeredSpikes = findTriggeredEvents(AbsLFP_normalizedFiltered, LED);
% 
% %Preallocate
% epileptiformTime(:,4)= 0;
% 
% %Find light-triggered events 
% for i=1:size(epileptiformTime,1) 
%     %use the "ismember" function 
%     epileptiformTime(i,4)=ismember (epileptiformLocation(i,1), triggeredSpikes);
% end
% 
% %Store light-triggered events (s)
% triggeredEvents = epileptiformTime(epileptiformTime(:,4)>0, 1);



%% plot graph of normalized  data 

if threshold_multiple(3) == 1

figHandle = figure;
set(gcf,'NumberTitle','off', 'color', 'w'); %don't show the figure number
set(gcf,'Name', sprintf ('Overview of %s', FileName)); %select the name you want
set(gcf, 'Position', get(0, 'Screensize'));

lightpulse = LED > 1;

subplot (3,1,1)
reduce_plot (t, LFP_normalized, 'k');
hold on
reduce_plot (t, lightpulse - 2);

%plot artifacts (red), found in 2nd search
for i = 1:numel(artifacts(:,1)) 
    reduce_plot (t(artifacts(i,1):artifacts(i,2)), LFP_normalized(artifacts(i,1):artifacts(i,2)), 'r');
end

%plot onset markers
for i=1:numel(epileptiformTime(:,1))
reduce_plot ((onsetTimes(i)), (LFP_normalized(epileptiformLocation(i))), 'o');
end

%plot offset markers
for i=1:numel(epileptiformTime(:,2))
reduce_plot ((offsetTimes(i)), (LFP_normalized(epileptiformLocation(i,2))), 'x');
end

title (sprintf ('Overview of LFP (10000 points/s), %s', FileName));
ylabel ('LFP (mV)');
xlabel ('Time (s)');

subplot (3,1,2) 
reduce_plot (t, AbsLFP_normalizedFiltered, 'b');
hold on
reduce_plot (t, lightpulse - 1);

%plot spikes (artifact removed)
for i=1:size(locs_spike_2nd,1)
plot (t(locs_spike_2nd(i,1)), (DiffLFP_normalizedFiltered(locs_spike_2nd(i,1))), 'x')
end

title ('Overview of filtered LFP (bandpass: 1 to 100 Hz)');
ylabel ('LFP (mV)');
xlabel ('Time (s)');

subplot (3,1,3) 
reduce_plot (t(1:end-1), DiffLFP_normalizedFiltered, 'g');
hold on

% %plot onset markers
% for i=1:numel(locs_onset)
% plot (t(locs_spike(locs_onset(i))), (pks_spike(locs_onset(i))), 'o')
% end
 
%plot spikes 
for i=1:size(locs_spike_1st,1)
plot (t(locs_spike_1st(i,1)), (DiffLFP_normalizedFiltered(locs_spike_1st(i,1))), 'x')
end

% %plot artifacts, found in the 1st search
% for i=1:size(locs_artifact_1st(: ,1))
% plot (t(locs_artifact_1st(i,1)), (DiffLFP_normalizedFiltered(locs_artifact_1st(i,1))), 'o', 'MarkerSize', 12)
% end

% %plot offset markers
% for i=1:numel(locs_onset)
% plot ((offsetTimes(i)), (pks_spike(locs_onset(i))), 'x')
% end

title ('Peaks (o) in Derivative of filtered LFP');
ylabel ('Derivative (mV)');
xlabel ('Time (s)');

saveas(figHandle,sprintf('%s.png', FileName), 'png');

else
end

'successfully completed. Thank you for choosing to use The Epileptiform Detector'
