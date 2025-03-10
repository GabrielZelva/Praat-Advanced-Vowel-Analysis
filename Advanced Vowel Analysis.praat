# This script is designed for advanced vowel analysis. 
# It can take in a whole corpus at once, but also allows you to adjust most settings
# You only need to select the folder with your corpus and the output
# It is expected that in you corpus, each audio in .wav has a textgrid with the exact same name, for example:

#subject1.wav
#subject1.textgrid


##################################################################################################
# IF YOU ARE PHOTOSENSITIVE, BE CAREFUL
# PRAAT WILL FLICKER A LOT AND I MEAN A LOT
##################################################################################################

# If you have any questions or problems, feel free to contact me at:
# gabrielzelva@gmail.com

beginPause: "Corpus settings"
    comment: "-----------------------------------------------------------------------------------------------------------------------------------------------------------"
    comment: "Remember, the corresponding .wav and .TextGrid files in the corpus have to have the exact same name"
    comment: "-----------------------------------------------------------------------------------------------------------------------------------------------------------"
    comment: "Where do you have your corpus?"
	folder: "origin", "/path/to/your/corpus"
    comment: "In which folder do you want to save the results?"
	folder: "output", "/path/to/your/output/folder"
    comment: "Which TextGrid tier contains the phonemes?"
	integer: "tier", 2
    comment: "-----------------------------------------------------------------------------------------------------------------------------------------------------------"
    comment: "What kind of analysis do you need?"
    comment: "Midpoint - only analyses the value at the middle of the segment"
    comment: "Mean - analyses the whole segment and returns the mean value"
    comment: "(Mean may give errors for really short segments)"
    choice: "mode", 1
        option: "Midpoint"
        option: "Mean"
    comment: "You may change which labels get analysed: (use regex)"
    sentence: "target", "a|e|i|o|u"
endPause: "Go to Acoustic settings", 1

origin$ = origin$ + "/"

output$ = output$ + "/"

if  mode$ == "Mean"
	
    beginPause: "Acoustic settings"
    comment: "Pitch settings"
	integer: "pitchFloor", 75
	integer: "pitchCeiling", 600
    real: "maximumPeriodFactor", 1.3
    comment: "-----------------------------------------------------------------------------------------------------------------------------------------------------------"
	comment: "Formant settings"
	real: "timeStep", 0
	real: "formantCeiling", 5500
	real: "windowLength", 0.025
	real: "preemphasis", 50
    comment: "-----------------------------------------------------------------------------------------------------------------------------------------------------------"
	comment: "Intensity settings"
    comment: "Ignore the air pressure constant added by the recording system?"
        choice: "subtractMean", 1
        option: "yes"
        option: "no"
    comment: "What extraction method would you like to use?"
        choice: "method", 1
        option: "energy"
        option: "sones"
        option: "dB"
    endPause: "Start the analysis", 1

elif mode$ == "Midpoint"

    beginPause: "Acoustic settings"
    comment: "Pitch settings"
	integer: "pitchFloor", 75
	integer: "pitchCeiling", 600
    choice: "interpolation", 1
        option: "nearest"
        option: "linear"
    comment: "-----------------------------------------------------------------------------------------------------------------------------------------------------------"
	comment: "Formant settings"
	real: "timeStep", 0
	real: "formantCeiling", 5500
	real: "windowLength", 0.025
	real: "preemphasis", 50
    comment: "-----------------------------------------------------------------------------------------------------------------------------------------------------------"
	comment: "Intensity settings"
    comment: "Ignore the air pressure constant added by the recording system?"
        choice: "subtractMean", 1
        option: "yes"
        option: "no"
    comment: "What interpolation method would you like to use?"
        optionmenu: "method", 3
        option: "nearest"
        option: "linear"
        option: "cubic"
        option: "sinc70"
        option: "sinc700"
    endPause: "Start the analysis", 1

endif

# Clear Praat
select all
if  numberOfSelected () <> 0
    pause "This script will close everything you have open in Praat, make sure everything important is saved!"
	Remove
endif

Create Strings as file list: "files", origin$ +"*.TextGrid"
nFiles = Get number of strings

for file from 1 to nFiles
    # Set up for the analisis loop 
    selectObject: "Strings files"
    filename$ = Get string: file
    basename$ = filename$ - ".TextGrid"

    Read from file: origin$ + basename$ + ".wav"
    Rename: "soundwave"

    Read from file: origin$ + basename$ + ".TextGrid"
    Rename: "segmentation"

    resultsFile$ = output$ + "results_" + basename$ + ".txt"

    appendFileLine: resultsFile$, "Source of the data", tab$, "Vowel", tab$, "Interval n.", tab$, "F0(Hz)", tab$, "F1(Hz)", tab$, "F2(Hz)", tab$, "F3(Hz)", tab$, "F4(Hz)", tab$, "Intensity(dB)", tab$, "Duration(ms)"
   
    fileDuration = Get end time

    # Mean loop
    if mode$ == "Mean"
        nIntervals = Get number of intervals: tier
        for interval from 1 to nIntervals

            # Locate the segment and get duration
            select TextGrid segmentation
            label$ = Get label of interval: tier, interval
            start = Get starting point: tier, interval
            end = Get end point: tier, interval
            duration = end - start

            if index_regex(label$, target$)

                # Take the segment out of the main soundwave
                # However, we need to take quite a bit of context, because small segments may be shorter then windows
                select Sound soundwave

                startContext = start - 5
                if startContext < 0
                    startContext = 0
                endif

                endContext = end + 5
                if endContext > fileDuration
                    endContext = fileDuration
                endif

                select Sound soundwave
                Extract part: startContext, endContext, "rectangular", 1, "yes"
                Rename: "segment"

                # Extract F0
                select Sound segment
                To PointProcess (periodic, cc): pitchFloor, pitchCeiling
                meanPeriod = Get mean period: start, end, 1/pitchCeiling, 1/pitchFloor, maximumPeriodFactor
                f0 = 1/meanPeriod
                Remove

                # Extract the formants
                select Sound segment
                To Formant (burg): timeStep, 4, formantCeiling, windowLength, preemphasis
                f1 = Get mean: 1, start, end, "hertz"
                f2 = Get mean: 2, start, end, "hertz"
                f3 = Get mean: 3, start, end, "hertz"
                f4 = Get mean: 4, start, end, "hertz"
                Remove

                # Extract the intensity
                select Sound segment
                To Intensity: pitchFloor, timeStep, subtractMean$
                intensity = Get mean: start, end, method$
                Remove

                # Print the values and cleanup for the next cycle
                appendFileLine: resultsFile$, filename$, tab$, label$, tab$, interval, tab$, f0, tab$, f1, tab$, f2, tab$, f3, tab$, f4, tab$, intensity, tab$, duration
                select Sound segment
                Remove
            endif
        endfor

    # Midpoint loop
    elif mode$ == "Midpoint"
        nIntervals = Get number of intervals: tier
        for interval from 1 to nIntervals

            # Locate the segment and get duration
            select TextGrid segmentation
            label$ = Get label of interval: tier, interval
            start = Get starting point: tier, interval
            end = Get end point: tier, interval
            duration = end - start
            midpoint = start + duration/2

            if index_regex(label$, target$)

                # Take the segment out of the main soundwave
                # However, we need to take quite a bit of context, because small segments may be shorter then windows
                select Sound soundwave

                startContext = start - 5
                if startContext < 0
                    startContext = 0
                endif

                endContext = end + 5
                if endContext > fileDuration
                    endContext = fileDuration
                endif

                select Sound soundwave
                Extract part: startContext, endContext, "rectangular", 1, "yes"
                Rename: "segment"

                # Extract F0
                select Sound segment
                To Pitch: 0, pitchFloor , pitchCeiling
                f0 = Get value at time: midpoint, "Hertz", interpolation$
                Remove

                # Extract the formants
                select Sound segment
                To Formant (burg): timeStep, 4, formantCeiling, windowLength, preemphasis
                f1 = Get value at time: 1, midpoint, "hertz", "linear"
                f2 = Get value at time: 2, midpoint, "hertz", "linear"
                f3 = Get value at time: 3, midpoint, "hertz", "linear"
                f4 = Get value at time: 4, midpoint, "hertz", "linear"
                Remove

                # Extract the intensity
                select Sound segment
                To Intensity: pitchFloor, timeStep, subtractMean$
                intensity = Get value at time: midpoint, method$
                Remove


                # Print the values and cleanup for the next cycle
                appendFileLine: resultsFile$, filename$, tab$, label$, tab$, interval, tab$, f0, tab$, f1, tab$, f2, tab$, f3, tab$, f4, tab$, intensity, tab$, duration
                select Sound segment
                Remove
            endif
        endfor
    endif

    select Sound soundwave
    Remove
    select TextGrid segmentation
    Remove

endfor

selectObject: "Strings files"
Remove


    writeInfoLine: "                   Script finished                    ", newline$
    appendInfo: "Code by: Gabriel Pišvejc  Contact: gabrielzelva@gmail.com", newline$
    appendInfo: ".........................................................", newline$
    appendInfo: "...................;lx0KXNXKK0ko;........................", newline$
    appendInfo: "................:dOXNMMMMMMMMMMWXOd:.....................", newline$
    appendInfo: ".............'lONMMMMMMMMMMMMMMMMMMW0o'..................", newline$
    appendInfo: "............:0WMMMMWXOxolllodxOXWMMMMW0c.................", newline$
    appendInfo: "...........oXMMMMW0l,..........,lOWMMMMNo................", newline$
    appendInfo: "..........lNMMMMXo'...............lXMMMMNo...............", newline$
    appendInfo: ".........,0MMMMNl..................cXMMMMK;..............", newline$
    appendInfo: ".........lNMMMMO'..................'kMMMMWo..............", newline$
    appendInfo: ".........lNMMMMk....................xMMMMWo..............", newline$
    appendInfo: ".........,OWMMM0;..................,0MMMMNc..............", newline$
    appendInfo: "..........,OWMMWk,................'xWMMMMO,..............", newline$
    appendInfo: "............lONWW0c..............cOWMMMMK:...............", newline$
    appendInfo: "..............;ldkko,.........,lONMMMMW0:................", newline$
    appendInfo: "...........................:oxXWMMMMMWKxdxkkkdl:'........", newline$
    appendInfo: "........................,o0WMMMMMMMMMWWWMWWWWMMWKd,......", newline$
    appendInfo: ".....................'ckXMMMMMMMMMMMMMNkoc:;clkXMMKl.....", newline$
    appendInfo: "...................;d0WMMMMMMMMMMMMW0d;........;OWMXl....", newline$
    appendInfo: "................'ckNMMMMMMMMMMMMMXkc'...........;0MMO....", newline$
    appendInfo: "..............;dKWMMMMMMMMMMMMW0o,..............,OMM0....", newline$
    appendInfo: "...........,lONMMMMMMMMMMMWX0x:.................oNMWd....", newline$
    appendInfo: ".........:xXWMMMMMMMMMMMNOl,.................,ckNMWk'....", newline$
    appendInfo: "......,lONMMMMMMMMMMMWKx:................'lx0XWWXOl......", newline$
    appendInfo: "....:xXWMMMMMMMMMMMNOl'....................,:cc:,........", newline$
    appendInfo: "...dNMMMMMMMMMMMWKd;.....................................", newline$
    appendInfo: "...,lOXWMMMMMWXkc'.......................................", newline$
    appendInfo: "......,:lloll:,..........................................", newline$
    appendInfo: ".........................................................", newline$