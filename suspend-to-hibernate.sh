#!/bin/bash

exec &> >(logger -i -t suspend-to-hibernate)

source @etc@/suspend-to-hibernate.conf

rtc() {
    local delta=$1
    rtcwake -v -m no --date +$delta -d $WAKEALARM
    echo "wakealarm set for +$delta"
}

# For the following
# resuming: true iff the call is coming out of an rtc timeout
#   otherwise false, we're in the middle of the initial suspend call

# Call suspend again if this is a resume
#  script will be retriggered from suspend hook
suspend-cmd() {
    local resuming=$1; shift
    local comment=$1; shift
    if $resuming; then
	    echo "resuspend triggered: $comment"
	    systemctl suspend
    else
	    echo "suspend: $comment"
	    rtc "$HIBERNATE_TIME"
    fi
}

# Go straight to suspend if coming out of a resume
# Otherwise continue suspend with
#  a timeout of $SUSPEND_DELAY
#  and then the script is retriggered by resume
hibernate-cmd() {
    local resuming=$1; shift
    local comment=$1; shift
    if $resuming; then
	    echo "resuspend hibernate triggered: $comment"
	    systemctl hibernate
    else
	    echo "hibernate triggered: $comment"
	    rtc "$SUSPEND_DELAY"
    fi
}

# The logic of whether we should be suspending or hibernating
# Hibernate if off power, and battery percentage at or below
#   the threshold parameter
choose-suspend() {
    local resuming=$1; shift
    
    local onpower=$(</sys/class/power_supply/"$POWER"/online)
    if [[ $onpower = 1 ]]; then
	    suspend-cmd $resuming "on power"
    else
	    local curr=$(</sys/class/power_supply/"$BAT"/charge_now)
	    local max=$(</sys/class/power_supply/"$BAT"/charge_full)
	    local percent=$(bc -l <<< "scale=2; $curr/$max")
	    local threshold=$(bc -l <<< "scale=2; $percent > $BATTERY_THRESHOLD")
	    if [[ $threshold = 1 ]]; then
	        suspend-cmd $resuming "over threshold ($percent; $threshold; $curr; $max)"
	    else
	        hibernate-cmd $resuming "hibernate triggered ($percent; $threshold; $curr; $max)" 
	    fi
    fi
}

# Called with $1 == suspend,
#  continuing a suspend (maybe triggering a wake & hibernate)
choose-suspend-suspending() {
    choose-suspend false
}

# Called with $1 == resume, restart a suspend or initiate hibernate
choose-suspend-resuming() {
    choose-suspend true 
}

# Called with $1 == resume, check whether the
# wakeup is triggered by alarm, and if so,
# resuspend or hibernate
resume() {
    local alarm=$(cat /sys/class/rtc/"$WAKEALARM"/wakealarm)
    echo 0 >/sys/class/rtc/"$WAKEALARM"/wakealarm
    if [[ -z $alarm ]]; then
	    choose-suspend-resuming
    else
	    echo "normal wakeup"
    fi
}

# If going into suspend, check power state
#   and if necessary trigger a time out to hibernate
#   or else trigger a time out to recheck state
# If coming out of suspend, check alarm
#   and if so, trigger a suspend or hibernate
#   as needed by power state
main() {
    local state=$1; shift
    case $state in
	    suspend) choose-suspend-suspending;;
	    resume) resume;;
    esac
}

main "$@"
