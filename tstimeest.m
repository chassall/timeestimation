% Runs the Time Estimation experiment
%
% Other m-files required: Psychtoolbox

% Author: Cameron Hassall, Department of Psychiatry, University of Oxford
% email address: cameron.hassall@psych.ox.ac.uk
% Website: http://www.cameronhassall.com
% Sept 2019; Last revision: 27-Jan-2020

%% Standard pre-script code
close all; clear variables; clc; % Clear everything
rng('shuffle'); % Shuffle the random number generator

%% Run flags
demoMode = input('demoMode = (0/1): '); % 1 = demo, 0 = experiment
windowed = 1; % 1 = run in a window, 0 = run fullscreen
sendTriggers = 0; % 1 = send EEG triggers, 0 = no triggers

%% Set up parallel port and triggers
if sendTriggers
    [portobject,portaddress] = OpenIOPort;
    io64( portobject, portaddress,0);
end

% These will be summed when triggers are sent
blockCodes = [10 20 30 40 50 60];
eventCodes = 1:9;


%% Define control keys
KbName('UnifyKeyNames'); % Ensure that key names are mostly cross-platform
ExitKey = KbName('ESCAPE'); % Exit program
spacebar = KbName('SPACE');
leftKey = KbName('LeftArrow');
rightKey = KbName('RightArrow');
onTimeKey = KbName('UpArrow');
leftKey = KbName('f');
rightKey = KbName('j');


%% Display Settings

% Lab: Acer XB270H
viewingDistance = 1000; % mm, approximately
screenWidth = 640; % mm
screenHeight = 381; % mm

% Cam's iMac
% viewingDistance = 690; % mm, approximately
% screenWidth = 595; % mm
% screenHeight = 336; % mm

% % Cam's laptop (Macbook Air)
% viewingDistance = 560; % mm, approximately
% screenWidth = 286; % mm
% screenHeight = 179; % mm


%% Participant info and data
participantData = [];
while ~demoMode
    p_number = input('Enter the participant number:\n','s');  % get the subject name/number
    rundate = datestr(now, 'yyyymmdd-HHMMSS');
    filename = strcat('tstimeest_', rundate, '_', p_number, '.txt');
    mfilename = strcat('tstimeest_', rundate, '_', p_number, '.mat');
    checker1 = ~exist(filename,'file');
    checker2 = isnumeric(str2double(p_number)) && ~isnan(str2double(p_number));
    if checker1 && checker2
        break;
    else
        disp('Invalid number, or filename already exists.');
        WaitSecs(1);
    end
end

%% Experiment Parameters

% * * * High-level task variables
margins = [.100 .100 .100 NaN NaN NaN]; % Response thresholds, in s, as per Miltner, Braun, and Coles, 1997
marginAdjust = 0.010;  % Staircase height, in s, as per Miltner, Braun, and Coles, 1997

% Target intervals, in seconds
goalDurations = [0.8 1.65 2.5 0.8 1.65 2.5];

% Comparison durations, in seconds
% I.e., these are the possible computer guesses for the "judge" trials
comparisonDurations = nan(length(goalDurations),5);
for b = 4:6
    comparisonDurations(b,1) = goalDurations(b)/(1.25^2);
    comparisonDurations(b,2) = goalDurations(b)/1.25;
    comparisonDurations(b,3) = goalDurations(b);
    comparisonDurations(b,4) = goalDurations(b)*1.25;
    comparisonDurations(b,5) = goalDurations(b)*(1.25^2);
end

% * * * Block and trial details * * *

% Number of trials per block
if demoMode
    nListenTrials = 5; % How many beeps from the metronome
    nTrials = 5; % Do/Judge Trials per block 266 seconds
    blockOrder = [1 2 4 5]; % Two do, two judge
else
    nListenTrials = 5;
    nTrials = 10; % Was around 23 minutes for 20 trials
    blockOrderNonrandom = [1 2 3 4 5 6 1 2 3 4 5 6 1 2 3 4 5 6 1 2 3 4 5 6 1 2 3 4 5 6 1 2 3 4 5 6]; % Was around 23 minutes for 12 blocks, this should take 35 minutes
    blockOrder = Shuffle(blockOrderNonrandom);
end

% Do blocks: 1-3 (3 target intervals)
% Judge blocks: 4-6 (3 target intervals)
blockInstructions = {'do','do','do','judge','judge','judge'};

% Determine block/trial order
blockAndTrialOrder = [];
for b = 1:length(blockOrder)
    thisBlock = blockOrder(b);
    switch thisBlock
        case {1,2,3} % "Do" trials
            blockAndTrialOrder(b,:) = nan(1,nTrials);
            
        case {4,5,6} % "Judge" trials
            % All trials types (1-5) repeated up to nTrials/5 times
            % Each trial type is a different comparison duration (i.e., the
            % computer's guess)
            theseTrials = repmat(1:5,1,nTrials/5);
            theseTrials = Shuffle(theseTrials); % Random order
            blockAndTrialOrder(b,:) = theseTrials';
    end
end

% * * * Stim properties * * *

% Visual
bgColour = [64 64 64];
textColour = [255 255 255];
fixationColour = [255 255 255];
responseColour = [128 128 128];
metDeg = 2;
textSize = 24; % Instructions, etc. (in "pnts" or something)
textOffsetDeg = 1.75; % Some text might appear below the metronome/fixation cross - this is the offset, in degrees
fixCrossDimDeg = 1; % Fixation cross width/heigth (degrees)
fbWidthDeg = 2; % Feedback width (degrees)

% Audio
sampleRate = Snd('DefaultRate');
InitializePsychSound
pahandle = PsychPortAudio('Open', [], [], [], sampleRate, 2);
frequency = 400;
durationSec = 0.050;
fVolume = 0.4;
nSample = sampleRate*durationSec;
soundVec = sin(2*pi*frequency*(1:nSample)/sampleRate);
rampPoint = round((1/8)*length(soundVec));
onsetSlope = (rampPoint-0)/(rampPoint-1);
offsetSlope = (0-rampPoint)/(length(soundVec)-rampPoint);
envelope = [onsetSlope:onsetSlope:rampPoint (rampPoint-offsetSlope):offsetSlope:-offsetSlope];
%envelope = normalize(envelope,'range');
envelope = envelope ./ max(envelope);
soundVec = fVolume*envelope.*soundVec; % Adjust volume/ramp
soundVec = [soundVec; soundVec];
PsychPortAudio('FillBuffer', pahandle, soundVec);
PsychPortAudio('Start',pahandle); % Play one tone

% High-level variables
totalPoints = 0;

%% Experiment
tic;
try
    
    % Open a fullscreen window to get the display resolution
    Screen('Preference', 'SkipSyncTests', 1);
    [~, rec] = Screen('OpenWindow', 0, bgColour);
    fullRec = rec;
    Screen('CloseAll');
    
    if windowed
        rec = [0 0 1200 1000];
        windowWidth = ((rec(3)-rec(1))/fullRec(3))*screenWidth;
        windowHeight = ((rec(4)-rec(2))/fullRec(4))*screenHeight;
        [win, rec] = Screen('OpenWindow', 0, bgColour,rec, 32, 2);
    else
        HideCursor();
        ListenChar(2);
        rec = fullRec;
        windowWidth = screenWidth; % Hard-coded above somewhere
        windowHeight = screenHeight;
        [win, rec] = Screen('OpenWindow', 0, bgColour,rec, 32, 2);
    end
    
    % Set screen properties
    Screen('BlendFunction', win, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    Screen(win,'TextFont','Arial');
    Screen(win,'TextSize',textSize);
    
    % Get screen properties
    refreshRate = Screen('GetFlipInterval',win);
    horRes = rec(3);
    verRes = rec(4);
    xmid = round(rec(3)/2);
    ymid = round(rec(4)/2);
    horizontalPixelsPerMM = horRes/windowWidth;
    verticalPixelsPerMM = verRes/windowHeight;
    
    % * * * Compute stim dimensions, in pixels * * *
    
    % Metronome
    metMM = 2 * viewingDistance *tand(metDeg/2);
    metPix = metMM*horizontalPixelsPerMM;
    metRect = [xmid - metPix/2 ymid - metPix/2 xmid + metPix/2 ymid + metPix/2];
    
    % Text (below metronome/fixation)
    textOffsetMM = 2 * viewingDistance *tand(textOffsetDeg/2);
    textOffsetPx = textOffsetMM * verticalPixelsPerMM;
    
    % Fixation cross
    fixCrossDimMM = 2 * viewingDistance *tand(fixCrossDimDeg/2);
    fixCrossDimPix = fixCrossDimMM*horizontalPixelsPerMM;
    xCoords = [-fixCrossDimPix/2 fixCrossDimPix/2 0 0];
    yCoords = [0 0 -fixCrossDimPix/2 fixCrossDimPix/2];
    allCoords = [xCoords; yCoords];
    lineWidthPix = 4;
    
    % Feedback
    fbMM = 2 * viewingDistance *tand(fbWidthDeg/2);
    fbPix = fbMM*horizontalPixelsPerMM;
    fbRect = [xmid - fbPix/2 ymid - fbPix/2 xmid + fbPix/2 ymid + fbPix/2];
    
    % * * * Load images ***
    
    % Metronome
    [met, ~, metAlpha] = imread('./images/metronome-3372250_640.png');
    met(:,:,4) = metAlpha;
    met(:,:,1:3) = 255;
    metTexture = Screen('MakeTexture', win, met);
    
    cbInc = [255 255 255];
    cbCorr = [255 255 255];
    
    % Correct feedback
    %[cor, ~, corAlpha] = imread('check-mark-2025986_640.png');
    [cor, ~, corAlpha] = imread('./images/hook-1727484_640.png');
    cor(:,:,4) = corAlpha;
    %cor(:,:,1:3) = 255;
    cor(:,:,1) = cbCorr(1);
    cor(:,:,2) = cbCorr(2);
    cor(:,:,3) = cbCorr(3);
    corTexture = Screen('MakeTexture', win, cor); 
    
    % Incorrect feedback
    % [inc, ~, incAlpha] = imread('false-2061132_640.png');
    % [inc, ~, incAlpha] = imread('red-31226_640.png');
    % [inc, ~, incAlpha] = imread('cancel-146131_640.png');
    [inc, ~, incAlpha] = imread('./images/false-2061132_640.png');
    inc(:,:,4) = incAlpha;
    inc(:,:,1) = cbInc(1);
    inc(:,:,2) = cbInc(2);
    inc(:,:,3) = cbInc(3);
    incTexture = Screen('MakeTexture', win, inc);
    
    % Too fast
    % [tooFast, ~, tooFastAlpha] = imread('downarrow-38632_640.png');
    [tooFast, ~, tooFastAlpha] = imread('./images/icon-157349_640_early.png');
    tooFast(:,:,4) = tooFastAlpha;
    tooFast(:,:,1) = cbInc(1);
    tooFast(:,:,2) = cbInc(2);
    tooFast(:,:,3) = cbInc(3);
    tooFastTexture = Screen('MakeTexture', win, tooFast);
    
    % Too slow
    % [tooSlow, ~, tooSlowAlpha] = imread('uparrow-38632_640.png');
    [tooSlow, ~, tooSlowAlpha] = imread('./images/icon-157349_640_late.png');
    tooSlow(:,:,4) = tooSlowAlpha;
    tooSlow(:,:,1) = cbInc(1);
    tooSlow(:,:,2) = cbInc(2);
    tooSlow(:,:,3) = cbInc(3);
    tooSlowTexture = Screen('MakeTexture', win, tooSlow);
    
    if ~demoMode
        DrawFormattedText(win,'Demographics\n\nPlease read the following questions, then type your answer and press ''enter''\nTo leave a question blank, press ''enter'' twice without entering any text beforehand\nPlease inform the experimenter if you wish to change a response\n\n(press any key to proceed)','center','center',textColour);
        Screen('Flip',win);
        KbReleaseWait(-1);
        KbPressWait(-1);
        
        KbReleaseWait(-1);
        age = Ask(win,'What is your age?  ', textColour,bgColour,'GetChar','center','center',textSize);
        Screen('Flip',win);
        
        KbReleaseWait(-1);
        sex = Ask(win,'What is your sex?  ', textColour,bgColour,'GetChar','center','center',textSize);
        Screen('Flip',win);
        
        KbReleaseWait(-1);
        hand = Ask(win,'Are you left-handed or right-handed (left/right)?  ', textColour,bgColour,'GetChar','center','center',textSize);
        Screen('Flip',win);
        
        % Save participant's info (should be redundant with run sheet)
        run_line = [num2str(p_number) ', ' datestr(now) ', ' age ', ' sex ',  ' hand];
        dlmwrite('participants.txt',run_line,'delimiter','', '-append');
        
        DrawFormattedText(win,'Thank you - press any key to read the task instructions','center','center',textColour);
        Screen('Flip',win);
        KbReleaseWait(-1);
        KbPressWait(-1);
        KbReleaseWait(-1);
    end
    
    % Display instructions
    instructions{1} = 'TIME ESTIMATION\n\nYou will play several rounds of ''Time Estimation''\nYour goal is to estimate a different duration each round\n\nSome rounds are ''do'' round - you will need to press a button when the correct amount of time has ellapsed\n\nOther rounds are ''judge'' rounds - the computer will respond, and you will indicate whether its response was correct or incorrect';
    instructions{2} = 'TASK DETAILS\n\nBefore beginning each round, you will listen to a metronome indicating the target duration\n\n''Do'' Trials\nAfter you hear a beep, wait the indicated time, then press the spacebar\nYou will then hear a beep indicating that a response has been made\nIf your response is correct, you will see a checkmark\nOtherwise, you will see a clock face indicating whether your guess was early or late\nCorrect guess (checkmark): +2 points, incorrect guess (early/late): -1 point\n\n''Judge'' Trials\nAfter the beep, the computer will guess the duration.\nYou will know when the computer has responded because you will hear another beep\nYou will then be asked to judge the computer''s guess by selecting either ''correct'' or ''incorrect'' which will appear on the left and right sides of the screen\n(side determined at random)\nMake a judgement by pressing either the left key (''f'') or right key (''j'')\nCorrect judgment (checkmark): +2 points, incorrect judgement (''x''), -1 point\n\nYour points will be converted to money at the end of the game and you will be paid (1 point = 1p)';
    instructions{3} = 'EEG QUALITY\n\nPlease try to minimize eye and head movements\n\nPlease keep your eyes on the + in the center of the display\nPlease do not tap your feet/hands or count\nYou will be given several rest breaks\nPlease use these opportunities to rest your eyes, as needed';
    instructions{4} = 'Any questions?';
    for i = 1:length(instructions)
        Screen(win,'TextSize',textSize);
        DrawFormattedText(win,[instructions{i} '\n\n(press any key to continue)\n\n\n\n'],'center','center',textColour);
        
        % Draw the stimuli
        if i > 1
            DrawFormattedText(win,'Do',(1/7)*horRes,verRes-2*fbPix,textColour);
            DrawFormattedText(win,'(correct)',(1/7)*horRes,verRes-0.2*fbPix,textColour);
            Screen('DrawTexture', win, corTexture, [], CenterRect(fbRect,[(1/7)*horRes verRes-fbPix (1/7)*horRes verRes-fbPix]));
            DrawFormattedText(win,'(early)',(2/7)*horRes,verRes-0.2*fbPix,textColour);
            Screen('DrawTexture', win, tooFastTexture, [], CenterRect(fbRect,[(2/7)*horRes verRes-fbPix (2/7)*horRes verRes-fbPix]));
            DrawFormattedText(win,'(late)',(3/7)*horRes,verRes-0.2*fbPix,textColour);
            Screen('DrawTexture', win, tooSlowTexture, [], CenterRect(fbRect,[(3/7)*horRes verRes-fbPix (3/7)*horRes verRes-fbPix]));  
            
            DrawFormattedText(win,'Judge',(5/7)*horRes,verRes-2*fbPix,textColour);
            DrawFormattedText(win,'(correct)',(5/7)*horRes,verRes-0.2*fbPix,textColour);
            Screen('DrawTexture', win, corTexture, [], CenterRect(fbRect,[(5/7)*horRes verRes-fbPix (5/7)*horRes verRes-fbPix]));
            DrawFormattedText(win,'(incorrect)',(6/7)*horRes,verRes-0.2*fbPix,textColour);
            Screen('DrawTexture', win, incTexture, [], CenterRect(fbRect,[(6/7)*horRes verRes-fbPix (6/7)*horRes verRes-fbPix]));
        
        end
        
        Screen('Flip',win);
        KbReleaseWait(-1);
        KbPressWait(-1);
    end
    
    % Block/trial loop
    for bi = 1:length(blockOrder)
        
        % Block type? (1-6)
        b = blockOrder(bi);
        
        % Display/play metronome
        Screen('DrawTexture', win, metTexture, [], metRect);
        Screen(win,'TextSize',textSize);
        DrawFormattedText(win,[blockInstructions{b} '\npress any key to listen\n\n(this is round ' num2str(bi) ' of ' num2str(length(blockOrder)) ')'],'center',ymid + textOffsetPx);
        Screen('Flip',win);
        KbReleaseWait(-1);
        KbPressWait(-1);
        
        Screen('DrawTexture', win, metTexture, [], metRect);
        Screen('Flip',win);
        WaitSecs(1);
        
        % Metronome trials
        for t = 1:nListenTrials
            
            % Mark each beep during the metronome trials
            if sendTriggers
                io64( portobject, portaddress, eventCodes(2));
            end
            
            % Play beep
            PsychPortAudio('Start',pahandle);
            
            if sendTriggers
                io64( portobject, portaddress, 0);
            end
            
            % Check for escape key
            [keyIsDown, ~, keyCode] = KbCheck();
            if keyCode(ExitKey)
                ME = MException('kh:escapekeypressed','Exiting script');
                throw(ME);
            end
            WaitSecs(goalDurations(b));
        end
        
        % Prompt to begin block
        Screen('DrawLines', win, allCoords,lineWidthPix, fixationColour, [xmid ymid], 2);
        Screen(win,'TextSize',textSize);
        DrawFormattedText(win,[blockInstructions{b} '\npress any key to begin'],'center',ymid + textOffsetPx);
        Screen('Flip',win);
        KbReleaseWait(-1);
        KbPressWait(-1);
        WaitSecs(1);
        
        % Trial loop
        for t = 1:nTrials
            
            % Trial type? (NaN for "do" trials, 1-5 for "judge" trials - see above)
            computerRespCondition = blockAndTrialOrder(bi,t); % NaN for "do" trials, or 1-5 for "judge" trials
            
            % Initialize trial variables
            preBeepTime = 0.4 + rand*0.2; % 400-600 ms
            preQTime = NaN;
            responseTime = NaN;
            responseCondition = NaN;
            fbCondition = NaN;
            participantResponse = NaN;
            computerRT = NaN;
            guessTime = NaN;
            participantResponse = NaN;
            participantJudgement = NaN;
            judgementMapping = NaN;
            preFeedbackTime = 0.4 + rand*0.2; % 400-600 ms
            thisTrialMargin = margins(b);
            
            % Draw fixation cross
            Screen('DrawLines', win, allCoords,lineWidthPix, fixationColour, [xmid ymid], 2);
            % DrawFormattedText(win,blockInstructions{b},'center',ymid + textOffsetPx);
            Screen('Flip',win);
            if sendTriggers
                io64( portobject, portaddress,blockCodes(b) + eventCodes(1));
                WaitSecs(0.002);
                io64( portobject, portaddress,0);
            end
            
            % Wait 400-600 ms before beep
            WaitSecs(preBeepTime);
            
            % Start beep
            if sendTriggers
                io64( portobject, portaddress,blockCodes(b) + eventCodes(2));
            end
            startTime = GetSecs();
            PsychPortAudio('Start',pahandle);
            if sendTriggers
                WaitSecs(0.002);
                io64( portobject, portaddress, 0);
            end
            
            if ismember(b, [1 2 3]) % "Do" trial
                
                % Get button press
                while 1
                    [~, keyPressTime, keyCode] = KbCheck();
                    if keyCode(spacebar)
                        if sendTriggers
                            io64( portobject, portaddress,blockCodes(b) + eventCodes(3));
                        end
                        % End beep
                        PsychPortAudio('Start',pahandle)
                        endTime = keyPressTime;
                        break;
                    elseif keyCode(ExitKey)
                        ME = MException('kh:escapekeypressed','Exiting script');
                        throw(ME);
                    end
                end
                
                if sendTriggers
                    WaitSecs(0.002);
                    io64( portobject, portaddress, 0);
                end
                
                % Check accuracy (response must be within certain margin of
                % target)
                responseTime = endTime - startTime;
                if responseTime < goalDurations(b) - margins(b)
                    responseCondition = 1;
                    fbCondition = 3; % Incorrect (early)
                elseif responseTime > goalDurations(b) + margins(b)
                    responseCondition = 2;
                    fbCondition = 5; % Incorrect (late)
                else
                    responseCondition = 3;
                    fbCondition = 4; % Correct
                end
                
                preFeedbackTime = 0.4 + rand*0.2; % 400-600 ms
                WaitSecs(preFeedbackTime);
                
                switch responseCondition
                    case 1
                        margins(b) = margins(b) + marginAdjust; % Expand margin
                    case 2
                        margins(b) = margins(b) + marginAdjust; % Expand margin
                    case 3
                        margins(b) = margins(b) - marginAdjust; % Shrink margin
                    otherwise
                        
                end
                
                % Make sure we don't get a negative window
                if margins(b) < 0
                    margins(b) = 0;
                end
                
                
            else % "Judge" trial
                
                % Determine mapping of judgement prompt
                % 1: left = correct, right = incorrect
                % 2: left = incorrect, right = correct
                judgementMapping = randi(2);
                
                % Computer's guess? (index 1-5, where 3 is correct - see
                % Macar and Vidal, 2003)
                computerRT = comparisonDurations(b,computerRespCondition);
                WaitSecs(computerRT);
                
                % End beep
                if sendTriggers
                    io64( portobject, portaddress,blockCodes(b) + eventCodes(3));
                end
                PsychPortAudio('Start',pahandle)
                
                if sendTriggers
                    WaitSecs(0.002);
                    io64( portobject, portaddress, 0);
                end
                
                preQTime = 0.4 + rand*0.2; % 400-600 ms
                WaitSecs(preQTime);
                
                Screen(win,'TextSize',textSize);
%                 Screen('DrawLines', win, allCoords,lineWidthPix, fixationColour, [xmid ymid], 2);
                switch judgementMapping
                    case 1
                        DrawFormattedText(win,'on time?\nyes (''f'')    no (''j'')','center','center',textColour);
                    case 2
                        DrawFormattedText(win,'on time?\nno (''f'')    yes (''j'')','center','center',textColour);
                end
                
                % DrawFormattedText(win,blockInstructions{b},'center',ymid + textOffsetPx);
                if sendTriggers
                    io64( portobject, portaddress,blockCodes(b) + eventCodes(4));
                end
                Screen('Flip',win);
                if sendTriggers
                    WaitSecs(0.002);
                    io64( portobject, portaddress, 0);
                end
                
                while 1
                    [~, keyPressTime, keyCode] = KbCheck();
                    if keyCode(leftKey) || keyCode(rightKey)
                        
                        if keyCode(leftKey)
                            participantResponse = 1;
                        else
                            participantResponse = 2;
                        end
                        
                        if sendTriggers
                            io64( portobject, portaddress,blockCodes(b) + eventCodes(5));
                        end
                        
                        % Fixation cross
                        Screen('DrawLines', win, allCoords,lineWidthPix, fixationColour, [xmid ymid], 2);
                        % DrawFormattedText(win,blockInstructions{b},'center',ymid + textOffsetPx);
                        Screen('Flip',win);
                        endTime = keyPressTime;
                        break;
                    elseif keyCode(ExitKey)
                        ME = MException('kh:escapekeypressed','Exiting script');
                        throw(ME);
                    end
                end
                guessTime = endTime - startTime;
                
                switch judgementMapping
                    case 1
                        participantJudgement = participantResponse == 1;
                    case 2
                        participantJudgement = participantResponse == 2;
                end
                
                if computerRespCondition == 3 && participantJudgement % Correct judgement
                    fbCondition = 2;
                elseif computerRespCondition ~= 3 && ~participantJudgement % Correct judgement
                    fbCondition = 2;
                else % Incorrect judgement
                    fbCondition = 1;
                end
                
            end
            
            if sendTriggers
                WaitSecs(0.002);
                io64( portobject, portaddress, 0);
            end
            
            % Wait 400-500 ms before feedback
            WaitSecs(preFeedbackTime);
            
            % Display feedback for 1 second
            switch fbCondition
                case 1 % Judge, incorrect
                    Screen('DrawTexture', win, incTexture, [], fbRect);
                    fbCode = eventCodes(6);
                    totalPoints = totalPoints - 1;
                case 2 % Judge, correct
                    Screen('DrawTexture', win, corTexture, [], fbRect);
                    fbCode = eventCodes(7);
                    totalPoints = totalPoints + 2;
                case 3 % Do, incorrect (too fast, "slow down")
                    Screen('DrawTexture', win, tooFastTexture, [], fbRect);
                    fbCode = eventCodes(8);
                    totalPoints = totalPoints - 1;
                case 4 % Do, correct
                    Screen('DrawTexture', win, corTexture, [], fbRect);
                    fbCode = eventCodes(7);
                    totalPoints = totalPoints + 2;
                case 5 % Do, incorrect (too slow, "speed up")
                    Screen('DrawTexture', win, tooSlowTexture, [], fbRect);
                    fbCode = eventCodes(9);
                    totalPoints = totalPoints - 1;
                    
            end
            Screen('Flip',win);
            if sendTriggers
                io64( portobject, portaddress,blockCodes(b) + fbCode);
                WaitSecs(0.002);
                io64( portobject, portaddress,0);
            end
            WaitSecs(1);
            
            % Check for escape key
            [keyIsDown, ~, keyCode] = KbCheck();
            if keyCode(ExitKey)
                ME = MException('kh:escapekeypressed','Exiting script');
                throw(ME);
            end
            
            thisLine = [b t preBeepTime responseTime computerRT computerRespCondition judgementMapping participantResponse participantJudgement guessTime preFeedbackTime fbCondition totalPoints thisTrialMargin];
            if ~demoMode
                dlmwrite(filename,thisLine,'delimiter', '\t', '-append');
            end
            participantData = [participantData; thisLine];
            
        end
        
        %         % Rest break - every nTrials/2 trials
        %         if t == nTrials/2
        %             DrawFormattedText(win,['rest break - press any key to continue\n\ntotal points: ' num2str(totalPoints)],'center','center',textColour);
        %             Screen('Flip',win);
        %             KbPressWait();
        %         end
    end
    
    toc
    
    % Save important variables
    if ~demoMode
        save(mfilename, 'participantData');
    end
    
    if sendTriggers
        CloseIOPort; %close trigger functions and triggers to eeg
    end
    
    % End of Experiment
    Screen(win,'TextSize',textSize);
    DrawFormattedText(win,['end of experiment - thank you\n\npoint total: ' num2str(totalPoints)],'center','center',textColour);
    Screen('Flip',win);
    WaitSecs(2);
    
    % Close the Psychtoolbox window and bring back the cursor and keyboard
    Screen('CloseAll');
    ListenChar();
    ShowCursor();
    
    % Display payout and whatnot
    disp('All done - good job!');
    
catch e
    
    PsychPortAudio('Close', pahandle);
    
    % Save important variables
    if ~demoMode
        save(mfilename, 'participantData');
    end
    
    if sendTriggers
        CloseIOPort; %close trigger functions and triggers to eeg
    end
    
    % Close the Psychtoolbox window and bring back the cursor and keyboard
    Screen('CloseAll');
    ListenChar();
    ShowCursor();
    
    % Display payout and whatnot
    disp(['Points: ' num2str(totalPoints)]);
    
    rethrow(e);
    
end

PsychPortAudio('Close', pahandle);

% Save important variables
if ~demoMode
    save(mfilename, 'participantData');
end

if sendTriggers
    CloseIOPort; %close trigger functions and triggers to eeg
end

% Close the Psychtoolbox window and bring back the cursor and keyboard
Screen('CloseAll');
ListenChar();
ShowCursor();

% Display payout and whatnot
disp(['Points: ' num2str(totalPoints)]);

return;

%% Scratch

frequency = 400;
durationSec = 0.050;
fVolume = 0.4;
sampleRate = Snd('DefaultRate');
nSample = sampleRate*durationSec;
soundVec = sin(2*pi*frequency*(1:nSample)/sampleRate);
rampPoint = round((1/8)*length(soundVec));
onsetSlope = (rampPoint-0)/(rampPoint-1);
offsetSlope = (0-rampPoint)/(length(soundVec)-rampPoint);
envelope = [onsetSlope:onsetSlope:rampPoint (rampPoint-offsetSlope):offsetSlope:-offsetSlope];
envelope = normalize(envelope,'range');
soundVec = fVolume*envelope.*soundVec; % Adjust volume/ramp

Snd('Play', soundVec, sampleRate);
WaitSecs(0.5);
Snd('Play', soundVec, sampleRate);

%% Scratch
% For finding the propper text sixe
targetSizeDeg = 2;
targetSizeMM = 2 * viewingDistance *tand(targetSizeDeg/2);
targetSizePix = targetSizeMM*horizontalPixelsPerMM;
yPositionIsBaseline = 1;
Screen(win,'TextFont','Arial');
allWidths = [];
textSizes = 1:36;
for s = 8:36
    fbDouble = 10003;
    % fbDouble = 10007;
    %fbDouble = 'test';
    Screen(win,'TextSize',s);
    bounds=TextBounds(win,fbDouble,yPositionIsBaseline)
    allWidths = [allWidths bounds(3)];
    x0=100;
    y0=100;
    Screen('DrawText',win,fbDouble,x0,y0,128,255,yPositionIsBaseline);
    Screen('FrameRect',win,128,OffsetRect(bounds,x0,y0));
    Screen('Flip',win);
end
[closestPx,closestPxI] = min(abs(targetSizePix-allWidths));
closestSize = textSizes(closestPxI)
Screen(win,'TextSize',closestSize);
bounds=TextBounds(win,fbDouble,yPositionIsBaseline);
x0=100;
y0=100;
Screen('DrawText',win,fbDouble,x0,y0,128,255,yPositionIsBaseline);
Screen('FrameRect',win,128,OffsetRect(bounds,x0,y0));
Screen('Flip',win);

%% Scratch

while 1
    KbReleaseWait(-1);
    KbPressWait(-1);
    tic;
    Snd('Play', soundVec, sampleRate);
    toc
end

%%
InitializePsychSound
pahandle = PsychPortAudio('Open', [], [], [], sampleRate, 2);


PsychPortAudio('FillBuffer', pahandle, [soundVec; soundVec]);

while 1
    
    KbReleaseWait(-1);
    KbPressWait(-1);
    vbl = PsychPortAudio('Start',pahandle)
end

PsychPortAudio('Close', pahandle);