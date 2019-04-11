#!/bin/bash

# VERSION: 2.1.1 (05.04.2019;DD.MM.YYYY)
# AUTHOR: Marvin Vogt (LunDev)
# LICENSE: GNU General Public License v3.0
# WEBSITE: https://github.com/LunDev/latex-generator

# GENERAL INFORMATION:
#  This script relies on the two files template/abgabeXX.tex & template/taskX.tex as templates.
#  Please customize them to your liking before using this generator.

# USAGE:
#  This script will ask for configuration information during execution:
#  1. BlattNr
#  2. TaskList
#  3. BlattPrefix
#  4. CustomHeadings
#  5. Placeholder
#
#  BlattNr is a number (1 or 2 digits)
#   single digits will be paddded
#
#  TaskList is a comma (",") separated list:
#   Every entry is a series of characters (please avoid special chars : ) )
#   You can use several options for advanced generation, only one option is supported per entry:
#    To hide the heading for a task, prefix the entry with "!"
#    To only generate the heading, prefix the entry with "-"
#    To indicate subsections, please prefix the entry with ">"
#    To combine subsection headings into the previous entry, prefix the entry with "->"
#     This option works recursively, so don't use it on the first entry.
#
#  BlattPrefix prefixes every task excluding combined sub-headings with the BlattNr if enabled
#
#  CustomHeadings allows you to specify a custom heading for each entry
#   The custom heading will be placed into the \(sub)section tag after the entry itself.
#   This will only work for entries where the heading is not hidden!
#   Specify no custom heading (press enter without typing anything else) to use no custom heading on this entry.
#
#  Placeholder allows you to configure your own custom placeholder
#   The placeholder will be inserted into each file or after each heading if there is more than one heading in that file (obviously excluding the main file).
#   This option was added for all of you, who don't like the default placeholder "abc". No, I'm not looking at you @der_paddy

# COMPATIBILITY:
#  There's not guranteed support for any device/os-combo, but it "should" work on almost every system (the mac bug was fixed recently as well - grrr)

# ADDITIONAL NOTES:
#  I'm sorry for this poor code quality
#  If you took the time and improved it or found a bug, please contact me!

export terminal=$(tty)

function evaluateConfirmation() {
    local conf="$1"
    local lengConf=${#conf}
    if [ $lengConf -lt 1 ] || [ $conf == 'n' ] || [ $conf == 'N' ]; then
        echo "n"
    elif [ $conf == 'y' ] || [ $conf == 'Y' ] || [ $conf == 'j' ] || [ $conf == 'J' ]; then
        echo "y"
    else
        echo "x"
    fi
}

read -p 'BlattNr: ' blattNr

blattNrFin="$blattNr"

leng=${#blattNrFin}

if [ $leng -lt 1 ]; then
    echo "Sorry, too short"
    exit
elif [ $leng -lt 2 ]; then
    blattNrFin="0$blattNrFin"
elif [ $leng -gt 2 ]; then
    echo "Sorry, too long"
    exit
fi

echo "creating Blatt $blattNrFin"

blattDir="blatt$blattNrFin"
toAddToDir="/tasks"
slash="/"
taskDir="$blattDir$toAddToDir";
abgabeName="abgabe${blattNrFin}.tex"

if [ -d "$blattDir" ]; then
    echo 'BlattDir already exists, terminating ...'
    echo 'Please remove dir and try again'
	  exit
fi

mkdir $blattDir
mkdir $taskDir

read -p 'Tasks (comma separated, without spaces): ' IN

read -p 'Do you want to prefix every task with the BlattNr? (y/N): ' prefixToggle
prefixToggle=$(evaluateConfirmation $prefixToggle)
if [ $prefixToggle == 'x' ]; then
    echo "unknown option, only y,Y,j,J,n,N supported"
    exit
fi

if [ $prefixToggle == 'y' ]; then
    prefix="$blattNrFin."
else
    prefix=""
fi

# check tasks in task list
echo "will be creating tasks with the following options:"
counter=0
while IFS=',' read -ra ADDR; do
    for i in "${ADDR[@]}"; do
        # process $i
        override=false
        if [[ $i == \!* ]]; then
            # no-heading
            i=$(echo "$i" | sed -e "s/\!//")
            taskType[$counter]="no-heading"
            echo "$prefix$i: no heading, only file"
        elif [[ ${i:0:2} = "->" ]]; then
            # sub-heading, but no separate file
            i=$(echo "$i" | sed -e "s/\-//" -e "s/>//")
            taskType[$counter]="sub-heading-combined"
            # doing no $prefix here!
            override=true
            taskFilename[$counter]="$i" # doesn't matter, no file : )
            taskShowname[$counter]="$i"
            echo "$i: sub-heading, but no separate file"
        elif [[ $i == \-* ]]; then
            # heading-only
            i=$(echo "$i" | sed -e "s/\-//")
            taskType[$counter]="heading-only"
            echo "$prefix$i: only heading, no file"
        elif [[ $i == \>* ]]; then
            # sub-heading
            i=$(echo "$i" | sed -e "s/>//")
            taskType[$counter]="sub-heading"
            echo "$prefix$i: sub-heading & file"
        else
            # normal
            taskType[$counter]="normal"
            echo "$prefix$i: normal: heading & file"
        fi
        if [ "$override" = false ]; then
            taskFilename[$counter]="$i"
            taskShowname[$counter]="$prefix$i"
        fi
        let counter=counter+1
        maxCount=$counter
    done
done <<< "$IN"

read -p 'Do you want to insert custom headings? (y/N): ' cHeadingsToggle
cHeadingsToggle=$(evaluateConfirmation $cHeadingsToggle)
if [ $cHeadingsToggle == 'x' ]; then
    echo "unknown option, only y,Y,j,J,n,N supported"
    exit
fi

# collect custom heading texts
if [ $cHeadingsToggle == 'y' ]; then
    counter=0
    while [ $counter -lt $maxCount ]; do
        taskTypeL=${taskType[$counter]}
        if [ $taskTypeL = "sub-heading-combined" ] || [ $taskTypeL = "heading-only" ] || [ $taskTypeL = "sub-heading" ] || [ $taskTypeL = "normal" ]; then
            read -p "Insert a custom heading for ${taskShowname[$counter]} (Blank for no custom heading): " cHeadingOne < $terminal
            cHeadings[$counter]=$cHeadingOne
        fi
        let counter=counter+1
    done
fi

# final check
echo "will use the following custom headings:"
counter=0
while [ $counter -lt $maxCount ]; do
    if [ ${#cHeadings[$counter]} -lt 1 ]; then
        echo "${taskShowname[$counter]}: <blank>"
    else
        echo "${taskShowname[$counter]}: ${cHeadings[$counter]}"
    fi
    let counter=counter+1
done

read -p 'Specify your placeholder (abc): ' placeholder
if [ ${#placeholder} -lt 1 ]; then
    placeholder="abc"
fi

read -p 'Do you want to start the generator with this configuration? (Y/n): ' finalConfirmation
if [ ${#finalConfirmation} -lt 1 ]; then
    finalConfirmation='y'
fi
finalConfirmation=$(evaluateConfirmation $finalConfirmation)
if [ $finalConfirmation == 'x' ]; then
    echo "unknown option, only y,Y,j,J,n,N supported"
    exit
elif [ $finalConfirmation == 'n' ]; then
    echo "aborting"
    exit
fi

#if [ $taskTypeL = "no-heading" ] || [ $taskTypeL = "sub-heading-combined" ] || [ $taskTypeL = "heading-only" ] || [ $taskTypeL = "sub-heading" ] || [ $taskTypeL = "normal" ]; then

# write task files
counter=0
while [ $counter -lt $maxCount ]; do
    echo "Working on task: ${taskShowname[$counter]}"
    taskName="task${taskFilename[$counter]}.tex"
    fullFilename="$taskDir$slash$taskName"

    taskTypeL=${taskType[$counter]}
    if [ $taskTypeL = "no-heading" ] || [ $taskTypeL = "sub-heading" ] || [ $taskTypeL = "normal" ]; then
        while IFS= read -r line; do
            if [[ "$line" == %INSERT_HEADERS* ]]; then
                counterN=$((counter+1))
                written=false
                while [ $counterN -lt $maxCount ] && [ ${taskType[$counterN]} = "sub-heading-combined" ]; do
                    if [ ${#cHeadings[$counterN]} -lt 1 ]; then
                        insertCHeading=""
                    else
                        insertCHeading=" ${cHeadings[$counterN]}"
                    fi
                    echo "\\subsection*{${taskShowname[$counterN]})$insertCHeading}" >> "$fullFilename"
                    echo "$placeholder" >> "$fullFilename"
                    written=true
                    let counterN=counterN+1
                done
                if [ "$written" = false ]; then
                    echo "$placeholder" >> "$fullFilename"
                fi
            else
                echo "$line" | sed -e "s/abgabeXX/abgabe${blattNrFin}/g" >> "$fullFilename"
            fi
        done < "template/taskX.tex"
    fi
    let counter=counter+1
done

# write main file
echo "writing main file"
fullFilename="$blattDir$slash$abgabeName"
while IFS= read -r line; do
    if [[ "$line" == %INSERT_HEADERS* ]]; then
        echo "inserting headings"
        counter=0
        while [ $counter -lt $maxCount ]; do
            written=false

            if [ ${#cHeadings[$counter]} -lt 1 ]; then
                insertCHeading=""
            else
                insertCHeading=" ${cHeadings[$counter]}"
            fi

            taskTypeL=${taskType[$counter]}
            if [ $taskTypeL = "heading-only" ] || [ $taskTypeL = "normal" ]; then
                echo "\\section*{Aufgabe ${taskShowname[$counter]}$insertCHeading}" >> "$fullFilename"
                written=true
            elif [ $taskTypeL = "sub-heading" ]; then
                echo "\\subsection*{${taskShowname[$counter]})$insertCHeading}" >> "$fullFilename"
                written=true
            fi

            if [ $taskTypeL = "sub-heading" ] || [ $taskTypeL = "normal" ]; then
                echo "\\subfile{tasks/task${taskFilename[$counter]}}" >> "$fullFilename"
                written=true
            fi

            if [ "$written" = true ]; then
                echo "" >> "$fullFilename"
            fi
            let counter=counter+1
        done
        echo "continue writing file"
    fi
    echo "$line" | sed -e "s/aufgabenNrXX/$blattNrFin/g" >> "$fullFilename"
done < "template/abgabeXX.tex"

echo "DONE!"
