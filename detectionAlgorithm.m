%Program: Epileptiform Activity Detector 
%Author: Michael Chang (michael.chang@live.ca)
%Copyright (c) 2018, Valiante Lab
%Version 1.0


%% Clear All

close all
clear all
clc

%% Load .abf and excel data

    [FileName,PathName] = uigetfile ('*.abf','pick .abf file', 'F:\');%Choose abf file
    [x,samplingInterval,metadata]=abfload([PathName FileName]); %Load the file name with x holding the channel data(10,000 sampling frequency) -> Convert index to time value by dividing 10k
                                                                                         
%% create time vector
frequency = 1000000/samplingInterval; %Hz. si is the sampling interval in microseconds from the metadata
t = (0:(length(x)- 1))/frequency;
t = t';

%% Seperate .abf file signals into independent signals
LFP = x(:,1); 
LED = x(:,2);  %%To be used if you need to collect LED data in the future' switch column 1 to 2

%% normalize the data
LFP_normalized = LFP - LFP(1);

%% Fred's 1st round of detection

[onloc, offloc] = onoffDetect (x, t(1), t(end), samplingInterval*1e-6);

%% Filter the data
%Bandpass butter filter
[b,a] = butter(2, [[1 100]/(frequency/2)], 'bandpass');
LFP_normalizedFiltered = filtfilt (b,a,LFP_normalized);

%% Derivative of the data (absolute)
DiffLFP_normalizedFiltered = abs(diff(LFP_normalizedFiltered));

%% Find peaks

[pks, locs] = findpeaks (DiffLFP_normalizedFiltered)


%% plot graph of normalized  data 
figure;
set(gcf,'NumberTitle','off', 'color', 'w'); %don't show the figure number
set(gcf,'Name','Overview of Data'); %select the name you want
set(gcf, 'Position', get(0, 'Screensize'));

lightpulse = LED > 1;

subplot (3,1,1)
plot (t, LFP_normalized, 'k')
hold on
plot (t, lightpulse - 2)
title ('Overview of LFP (10000 points/s)');
ylabel ('LFP (mV)');
xlabel ('Time (s)');

subplot (3,1,2) 
plot (t, LFP_normalizedFiltered, 'b')
hold on
plot (t, lightpulse - 2)
title ('Overview of filtered LFP (bandpass: 1 to 100 Hz)');
ylabel ('LFP (mV)');
xlabel ('Time (s)');

subplot (3,1,3) 
plot (t(1:end-1), DiffLFP_normalizedFiltered, 'g')
hold on
plot (t(locs), (pks), 'o')
title ('Peaks (o) in Derivative of filtered LFP');
ylabel ('LFP (mV)');
xlabel ('Time (s)');
