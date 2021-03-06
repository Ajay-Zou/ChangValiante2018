function [figHandle, centerLFP] = plotEvent(figHandle, timeSeriesLFP, t, eventTime, locs_spike, appliedStimulus, context, frequency)
%plotEvent plots vectors of event vectors are detected by your algorithm
%   plotEvent function can also plot addition markers and features about
%   the event that were detected by the detection algorithm. There is also
%   an option to plot baseline recording preceding and following the event
%   to provide 'context' of the baseline around the event. timeSeries is
%   the LFP signal to be plotted. The background vector is the event
%   vector with 'context' (aka background context). The input varible 't'
%   is the timeSeries for 'time'. The function will also plot the location
%   of the spikes detected by the algorithm. 

%% Set variables to default values, if not specified
if nargin < 7
    context = 5;     %sec
    frequency = 10000;  %Hz
end

if nargin < 6
    context = 5;     %sec
    frequency = 10000;  %Hz
    appliedStimulus = [];
end

%Convert variables into Michael's Terms
% LFP_centered = timeSeriesLFP ;

  %% Plotting out detected Events with context     
    %make Event Vector
    onsetTime = (round(eventTime(1,1)*frequency));
    offsetTime = (round(eventTime(1,2)*frequency));
    eventVector = (onsetTime:offsetTime);  %SLE Vector    

    %make Background Vector
    if (onsetTime >= (context*frequency)+1 && (offsetTime+(context*frequency))<numel(timeSeriesLFP))
        backgroundVector = int64(onsetTime-(context*frequency):offsetTime+(context*frequency));   %Background Vector
    elseif (onsetTime < (context*frequency)+1)  %plus 1, because if the onsetTime happen to be exactly the same as, i.e. 5s, which is the preceding context, the starting index for the background vector will be 0 and cause an error
        backgroundVector = int64(1:offsetTime+(context*frequency));
    elseif ((offsetTime+(context*frequency))>numel(timeSeriesLFP))
        backgroundVector = int64(onsetTime-(context*frequency):numel(timeSeriesLFP));
    end

    %Plot figures
    figure(figHandle)
    centerLFP = (timeSeriesLFP(backgroundVector(1)));  %center the LFP 
    plot (t(backgroundVector),timeSeriesLFP(backgroundVector)-centerLFP ) %background
    hold on    
    plot (t(eventVector),timeSeriesLFP(eventVector)-centerLFP)     %SLE
    plot (t(onsetTime), timeSeriesLFP(onsetTime)-centerLFP , 'o', 'MarkerSize', 12, 'MarkerFaceColor', 'red') %onset marker
    plot (t(offsetTime), timeSeriesLFP(offsetTime)-centerLFP , 'o', 'MarkerSize', 12, 'MarkerFaceColor', 'red') %offset marker
    
    %Plot spikes detected by algorithm
    if ~isempty(locs_spike)
        indexSpikes = and(onsetTime<locs_spike, offsetTime>locs_spike); %Locate spikes between the onset and offset  
        plot (t(locs_spike(indexSpikes)), (timeSeriesLFP(locs_spike(indexSpikes))-centerLFP), 'x', 'color', 'green') %plot spikes (artifact removed)
    end

    %Plot applied stimulus (i.e., LED signal), if present
    if ~isempty(appliedStimulus)
        lightpulse = appliedStimulus;
        centerLED = abs(min(timeSeriesLFP(backgroundVector)-centerLFP));
        pulseHeight = max(lightpulse(backgroundVector)/4);
        plot (t(backgroundVector),((lightpulse(backgroundVector))/4)-(centerLED+pulseHeight) , 'b') %plot LED 
    end
end


    

