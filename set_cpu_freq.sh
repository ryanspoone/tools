#!/bin/bash
#
# Set a static CPU frequency.
#
# Usage:
#    set_cpu_freq <CPU frequency in kHz>
#
# Example for 3.2 GHz:
#    set_cpu_freq 3200000


main() {
  declare -r CPU_FREQUENCY="${1}"
  local new_max_frequency
  local new_min_frequency
  local this_governor_loc
  local this_max_freq_loc
  local this_min_freq_loc
  local cores
  local current_core
  local available_frequencies

  if [[ -z "${CPU_FREQUENCY}" ]]; then
    echo >&2
    echo 'ERROR: No frequency argument found.' >&2
    echo >&2
    exit 1
  fi

  if [[ ! "${CPU_FREQUENCY}" =~ ^[0-9]+$ ]]; then
    echo >&2
    echo 'ERROR: Invalid CPU frequency argument.' >&2
    echo >&2
    exit 1
  fi

  cores=$(nproc --all)

  if [[ -z "$cores" ]]; then
    cores=$(grep -c ^processor /proc/cpuinfo)
  fi

  if [[ -z "$cores" ]]; then
    cores=$(getconf _NPROCESSORS_ONLN)
  fi

  current_core=$((cores - 1))

  if [[ -f '/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies' ]]; then
    available_frequencies=$(cat '/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies')
  fi

  echo

  if [[ -n "${available_frequencies}" ]]; then
    echo "Available frequencies: ${available_frequencies}"
    echo
  fi

  echo "Changing core frequency to ${CPU_FREQUENCY} kHz"
  echo

  while [[ "${current_core}" -ge 0 ]]; do
    this_governor_loc="/sys/devices/system/cpu/cpu${current_core}/cpufreq/scaling_governor"
    this_max_freq_loc="/sys/devices/system/cpu/cpu${current_core}/cpufreq/scaling_max_freq"
    this_min_freq_loc="/sys/devices/system/cpu/cpu${current_core}/cpufreq/scaling_min_freq"

    # Make the governor aggressively use the minimum frequency
    #
    # Setting to minimum frequency instead of maximum because sometimes when
    # overclocking memory or other hardware, the max frequency will not set.
    # This forces the system to use the minimum frequency for that scenario.
    echo 'powersave' > "${this_governor_loc}"

    # Set new min-max values
    echo "${CPU_FREQUENCY}" > "${this_max_freq_loc}"
    echo "${CPU_FREQUENCY}" > "${this_min_freq_loc}"

    # Check that min-max is set
    new_max_frequency=$(cat "${this_max_freq_loc}")
    new_min_frequency=$(cat "${this_min_freq_loc}")

    printf 'CPU %s\t\tMin Frequency\t%s\t\tMax Frequency\t%s\n' \
    "${current_core}" "${new_min_frequency}" "${new_max_frequency}"

    if [[ ${new_min_frequency} -ne ${CPU_FREQUENCY} ]]; then
      echo 'WARNING: Minimum frequency not set.' >&2
    fi

    if [[ ${new_max_frequency} -ne ${CPU_FREQUENCY} ]]; then
      echo 'WARNING: Maximum frequency not set.' >&2
    fi

    current_core=$((current_core - 1))
  done

  echo
  echo 'Complete'
  echo
}

main "${@}"
