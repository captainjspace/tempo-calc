#!/usr/bin/env zsh
############################################################
# SyncBeats
# RT60=The total reverb time or reverberation time 
# is the time it takes for the sound pressure level 
# to reduce by 60 dB.
emulate -L zsh
#setopt xtrace errexit 
setopt shortloops;
############################################################
typeset -a delay_keys=( standard dotted triplet )
typeset -A delay_deco=(
    standard  " ♩  "
    dotted    " 🎵. "
    triplet   " 🎶 "
    eighth    " ♪  "
    sixteenth " ♬  "
)
typeset -a time_bits_up=( half_note  whole_note  two_whole four_note_drone )
typeset -a time_bits_down=( eighth sixteenth thirty-second sixty-fourth )
typeset -a time_order=( ${(@Oa)time_bits_down} quarter $time_bits_up );


# reverb terms
typeset -a reverb_keys=( tight room chamber hall cathedral space )
typeset -A reverb_common_names_map=(
  tight "Tight Ambiance"
  room "Room"
  chamber "Large Room/Chamber"
  hall "Hall"
  cathedral "Cathedral"
  space "Deep Space"
)

calc_delay() {
  local -A o=(); #options
  zparseopts -D -E -M -A o -- \
    n:=name -name:=name d:=delay -delay:=delay;

  # data table and quarter note delay
  local name="$o[--name]";
  local delay="${o[--delay]:=500}";
  
  typeset -gA delay_types=(
    standard "$delay"                       #baseline
    dotted   "$(( delay * 4 / 16  * 3 ))"   #dot_factor 
    triplet   "$(( delay * 2 / 3       ))"   #triplet factor
  );

  local -A reverb_times=()
  for r in {2..${#reverb_keys}}; do 
    reverb_times+=( "$reverb_keys[$r]" "$((1<<(r-2)))" );
  done;
  for dk in ${(@)delay_keys}; do
    for k v in ${(@kv)reverb_times};  
      delay_types+=( "${dk}:${delay_keys[(i)$dk]}:$k:${reverb_keys[(i)$k]}" "$((delay_types[$dk] * v))" );
  done;

  typeset -gA delay_types_c=()
  local template_key="%-36s"
  local idx=1000;
  for k v in "${(@kv)delay_types}"; do
    delay_types_c+=( "$k" "$v" )
    for i in {1..${#time_bits_up}}; do
      delay_types_c+=("$k:${time_order[(i)$time_bits_up[$i]]}:$time_bits_up[$i]" "$((v<<i))");
    done;
    for i in {1..${#time_bits_down}}; do
      delay_types_c+=( "$k:${time_order[(i)$time_bits_down[$i]]}:$time_bits_down[$i]" "$((v>>i))" );
    done;
  done;

  typeset -gA "$name";
  set -A "$name" ${(@kv)delay_types_c} 
  return 0;
}

calc_grid(){
  
  local bpm="${1:=120}"
  local -A g=(  
    bpm "$bpm"
    delay_factor 1
    reverb_factor 4.0          #1 bar
    predelay_factor 64.0       #1/64
    beats_ps "$((bpm/60.0))" #hertz
  );
  # frequency modulation
    ((g[hertz]=g[beats_ps])) 
    # chorus, flange, lfo modulation 
    ((g[kilohertz]=g[beats_ps] * 1000 ))
    
    # 1 bar delay
    ((g[seconds]=1.0/g[hertz]))
    ((g[ms]=g[seconds]*1000))

    #printf '%s : %s\n' "${(@kv)g}"
    # stock delay
    typeset -A delays=();
    calc_delay \
      --name delays \
      --delay $g[ms];

    #print -l ${(kv)delays}
    # pre-delay 1/64 for reverb or 
    ((g[predelay]=g[reverb_factor] / g[predelay_factor] * g[seconds]))
    printf '_%s : %s\n' "${(@kv)g}"
    printf '%s : %s\n' "${(@kv)delays}"
}

main() {
  local -A o=()
  zparseopts -D -E -M -A o -- b:=bpm -bpm:=bpm;
  printf '%s %s\n' ${(@kv)o}
  local bpm="${o[--bpm]:=120}";
  calc_grid $bpm | sort --mergesort
  return 0;
}
main "$@";



