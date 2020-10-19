# Time Estimation

In "do" trials, participants produce a target temporal interval. In "judge" trials, participants judge a computer-produced interval as on time or not. Task is blocked, i.e. 10 "do" trials or 10 "judge" trials. Each blocks is preceded by five metronome pulses of the target interval - either short (800 ms), medium (1650 ms), or long (2500 ms).

Requires: MATLAB, [Psychtoolbox](http://psychtoolbox.org/)

![trial overview](./images/trials.png "trial overview")

## EEG Triggers

Metronome Trigger

* 2: "Beep"

Block Triggers

* 10: "do", short  
* 20: "do", medium  
* 30: "do", long  
* 40: "judge", short  
* 50: "judge", medium  
* 60: "judge", long  

Trial Triggers  
* 1: Fixation  
* 2: Beep  
* 3: Response/Beep  
* 7: "Correct"  
* 8: "Early"  
* 9: "Late"  

Add block trigger to trial trigger, e.g. a "do", short response is 10 + 3 = 13
