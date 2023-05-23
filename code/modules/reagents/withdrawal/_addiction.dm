///base class for addiction, handles when you become addicted and what the effects of that are. By default you become addicted when you hit a certain threshold, and stop being addicted once you go below another one.
/datum/addiction
	///Name of this addiction
	var/name = "cringe code"
	///Higher threshold, when you start being addicted
	var/addiction_gain_threshold = 600
	///Lower threshold, when you stop being addicted
	var/addiction_loss_threshold = 800
	///Messages for each stage of addictions.
	var/list/withdrawal_stage_messages = list()
	///Rates at which you lose addiction (in units/second) if you are not on the drug at that time per stage
	var/addiction_loss_per_stage = list(0.5, 0.5, 1, 1.5)
	///Rate at which high sanity helps addiction loss
	var/high_sanity_addiction_loss = 2
	///Amount of drugs you need in your system to be satisfied
	var/addiction_relief_treshold = MIN_ADDICTION_REAGENT_AMOUNT
	///moodlet for light withdrawal
	var/light_withdrawal_moodlet = /datum/mood_event/withdrawal_light
	///moodlet for medium withdrawal
	var/medium_withdrawal_moodlet = /datum/mood_event/withdrawal_medium
	///moodlet for severe withdrawal
	var/severe_withdrawal_moodlet = /datum/mood_event/withdrawal_severe

	var/withdrawal_stage1_delay = 90
	var/withdrawal_stage1_deviation_range = 0
	var/withdrawal_stage2_delay = 90
	var/withdrawal_stage2_deviation_range = 0
	var/withdrawal_stage3_delay = 90
	var/withdrawal_stage3_deviation_range = 0
	


///Called when you gain addiction points somehow. Takes a mind as argument and sees if you gained the addiction
/datum/addiction/proc/on_gain_addiction_points(datum/mind/victim_mind)
	var/current_addiction_point_amount = victim_mind.addiction_points[type]
	if(current_addiction_point_amount < addiction_gain_threshold) //Not enough to become addicted
		return
	if(LAZYACCESS(victim_mind.active_addictions, type)) //Already addicted
		return
	become_addicted(victim_mind)


///Called when you become addicted
/datum/addiction/proc/become_addicted(datum/mind/victim_mind)
	LAZYSET(victim_mind.active_addictions_stage, type, 0)
	reset_deviation_and_cycle(victim_mind)
	SEND_SIGNAL(victim_mind.current, COMSIG_CARBON_GAIN_ADDICTION, victim_mind)
	victim_mind.current.log_message("has become addicted to [name].", LOG_GAME)

/// Resets the deviation and current cycle.
/datum/addiction/proc/reset_deviation_and_cycle(datum/mind/victim_mind)
	LAZYSET(victim_mind.active_addictions, type, 1) //Keeps withdrawal at first cycle.
	var/withdrawal_stage = LAZYACCESS(victim_mind.active_addictions_stage, type)
	switch(withdrawal_stage)
		if(0)
			LAZYSET(victim_mind.active_addictions_deviation, type, rand(0, withdrawal_stage1_deviation_range))
		if(1)
			LAZYSET(victim_mind.active_addictions_deviation, type, rand(0, withdrawal_stage2_deviation_range))
		if(2)
			LAZYSET(victim_mind.active_addictions_deviation, type, rand(0, withdrawal_stage3_deviation_range))


///Called when you lose addiction poitns somehow. Takes a mind as argument and sees if you lost the addiction
/datum/addiction/proc/on_lose_addiction_points(datum/mind/victim_mind)
	var/current_addiction_point_amount = victim_mind.addiction_points[type]
	if(!LAZYACCESS(victim_mind.active_addictions, type)) //Not addicted
		return FALSE
	if(current_addiction_point_amount > addiction_loss_threshold) //Not enough to stop being addicted
		return FALSE
	lose_addiction(victim_mind)
	return TRUE

/datum/addiction/proc/lose_addiction(datum/mind/victim_mind)
	victim_mind.current.clear_mood_event("[type]_addiction")
	SEND_SIGNAL(victim_mind.current, COMSIG_CARBON_LOSE_ADDICTION, victim_mind)
	to_chat(victim_mind.current, span_notice("You feel like you've gotten over your need for drugs."))
	end_withdrawal(victim_mind.current)
	LAZYREMOVE(victim_mind.active_addictions, type)
	LAZYREMOVE(victim_mind.active_addictions_stage, type)
	LAZYREMOVE(victim_mind.active_addictions_deviation, type)

/datum/addiction/proc/process_addiction(mob/living/carbon/affected_carbon, seconds_per_tick, times_fired)
	// One cycle is 2 seconds
	
	var/current_addiction_cycle = LAZYACCESS(affected_carbon.mind.active_addictions, type) //If this is null, we're not addicted
	var/current_addiction_deviation = LAZYACCESS(affected_carbon.mind.active_addictions_deviation, type)
	var/on_drug_of_this_addiction = FALSE
	for(var/datum/reagent/possible_drug as anything in affected_carbon.reagents.reagent_list) //Go through the drugs in our system
		for(var/addiction in possible_drug.addiction_types) //And check all of their addiction types
			if(addiction == type && possible_drug.volume >= addiction_relief_treshold) //If one of them matches, and we have enough of it in our system, we're not losing addiction
				if(current_addiction_cycle)
					end_withdrawal(affected_carbon) //stop the pain
				on_drug_of_this_addiction = TRUE
				break
	
	var/withdrawal_stage = LAZYACCESS(affected_carbon.mind.active_addictions_stage, type) 

	if(!on_drug_of_this_addiction && !HAS_TRAIT(affected_carbon, TRAIT_HOPELESSLY_ADDICTED))
		if(affected_carbon.mind.remove_addiction_points(type, addiction_loss_per_stage[withdrawal_stage + 1] * seconds_per_tick)) //If true was returned, we lost the addiction!
			return

	if(!current_addiction_cycle) //Dont do the effects if were not on drugs
		return FALSE

	switch(withdrawal_stage)
		if(0)
			if(current_addiction_cycle > (withdrawal_stage1_delay + current_addiction_deviation))
				LAZYSET(affected_carbon.mind.active_addictions_stage, type, withdrawal_stage + 1)
				reset_deviation_and_cycle(affected_carbon)
				withdrawal_enters_stage_1(affected_carbon)
				
		if(1)
			withdrawal_stage_1_process(affected_carbon, seconds_per_tick)
			if(current_addiction_cycle > (withdrawal_stage2_delay + current_addiction_deviation))
				LAZYSET(affected_carbon.mind.active_addictions_stage, type, withdrawal_stage + 1)
				reset_deviation_and_cycle(affected_carbon)
				withdrawal_enters_stage_2(affected_carbon)
		if(2)
			withdrawal_stage_2_process(affected_carbon, seconds_per_tick)
			if(current_addiction_cycle > (withdrawal_stage3_delay + current_addiction_deviation))
				LAZYSET(affected_carbon.mind.active_addictions_stage, type, withdrawal_stage + 1)
				reset_deviation_and_cycle(affected_carbon.mind)
				withdrawal_enters_stage_3(affected_carbon)
		if(3)
			withdrawal_stage_3_process(affected_carbon, seconds_per_tick)

	LAZYADDASSOC(affected_carbon.mind.active_addictions, type, 1 * seconds_per_tick) //Next cycle!

/// Called when addiction enters stage 1
/datum/addiction/proc/withdrawal_enters_stage_1(mob/living/carbon/affected_carbon)
	affected_carbon.add_mood_event("[type]_addiction", light_withdrawal_moodlet, name)

/// Called when addiction enters stage 2
/datum/addiction/proc/withdrawal_enters_stage_2(mob/living/carbon/affected_carbon)
	affected_carbon.add_mood_event("[type]_addiction", medium_withdrawal_moodlet, name)

/// Called when addiction enters stage 3
/datum/addiction/proc/withdrawal_enters_stage_3(mob/living/carbon/affected_carbon)
	affected_carbon.add_mood_event("[type]_addiction", severe_withdrawal_moodlet, name)

/datum/addiction/proc/end_withdrawal(mob/living/carbon/affected_carbon)
	LAZYSET(affected_carbon.mind.active_addictions_stage, type, 0)
	reset_deviation_and_cycle(affected_carbon.mind)
	affected_carbon.clear_mood_event("[type]_addiction")

/// Called when addiction is in stage 1 every process
/datum/addiction/proc/withdrawal_stage_1_process(mob/living/carbon/affected_carbon, seconds_per_tick)
	if(SPT_PROB(5, seconds_per_tick))
		to_chat(affected_carbon, span_danger("[withdrawal_stage_messages[1]]"))

/// Called when addiction is in stage 2 every process
/datum/addiction/proc/withdrawal_stage_2_process(mob/living/carbon/affected_carbon, seconds_per_tick)
	if(SPT_PROB(10, seconds_per_tick) )
		to_chat(affected_carbon, span_danger("[withdrawal_stage_messages[2]]"))

/// Called when addiction is in stage 3 every process
/datum/addiction/proc/withdrawal_stage_3_process(mob/living/carbon/affected_carbon, seconds_per_tick)
	if(SPT_PROB(15, seconds_per_tick))
		to_chat(affected_carbon, span_danger("[withdrawal_stage_messages[3]]"))
