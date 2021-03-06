#define UPGRADE_COOLDOWN	40
#define UPGRADE_KILL_TIMER	100


//This is called from human_attackhand.dm before grabbing happens.
//IT is called when grabber tries to grab this mob
//Override this for special grab behaviour.
//Returning 0 will make grab fail, returning 1 will suceed
/mob/living/proc/attempt_grab(var/mob/living/grabber)
	return 1

//As above, but called when someone tries to pull this mob
/mob/living/proc/attempt_pull(var/mob/living/grabber)
	return 1


///Process_Grab()
///Called by client/Move()
///Checks to see if you are grabbing or being grabbed by anything and if moving will affect your grab.
/client/proc/Process_Grab()
	if(isliving(mob)) //if we are being grabbed
		var/mob/living/L = mob
		if(!L.canmove && L.grabbed_by.len)
			L.resist() //shortcut for resisting grabs
	for(var/obj/item/grab/G in list(mob.l_hand, mob.r_hand))
		G.reset_kill_state() //no wandering across the station/asteroid while choking someone

/obj/item/grab
	name = "grab"
	icon = 'icons/mob/screen/generic.dmi'
	icon_state = "reinforce"
	flags = 0
	var/obj/screen/grab/hud = null
	var/mob/living/affecting = null
	var/mob/living/carbon/human/assailant = null
	var/state = GRAB_PASSIVE

	var/allow_upgrade = 1
	var/last_action = 0
	var/last_hit_zone = 0
	var/force_down //determines if the affecting mob will be pinned to the ground
	var/dancing //determines if assailant and affecting keep looking at each other. Basically a wrestling position

	layer = 21
	abstract = 1
	item_state = "nothing"
	w_class = 5.0


/obj/item/grab/New(mob/user, mob/victim)
	..()
	loc = user
	assailant = user
	affecting = victim

	if(affecting.anchored || !assailant.Adjacent(victim))
		qdel(src)
		return

	affecting.grabbed_by += src

	hud = new /obj/screen/grab(src)
	hud.icon_state = "reinforce"
	icon_state = "grabbed"
	hud.name = "reinforce grab"
	hud.master = src

	//check if assailant is grabbed by victim as well
	if(assailant.grabbed_by)
		for (var/obj/item/grab/G in assailant.grabbed_by)
			if(G.assailant == affecting && G.affecting == assailant)
				G.dancing = 1
				G.adjust_position()
				dancing = 1
	adjust_position()

//Used by throw code to hand over the mob, instead of throwing the grab. The grab is then deleted by the throw code.
/obj/item/grab/proc/throw_held()
	if(affecting)
		if(affecting.buckled)
			return null
		if(state >= GRAB_AGGRESSIVE)
			animate(affecting, pixel_x = 0, pixel_y = 0, 4, 1)
			return affecting
	return null


//This makes sure that the grab screen object is displayed in the correct hand.
/obj/item/grab/proc/synch()
	if(affecting)
		if(assailant.r_hand == src)
			hud.screen_loc = ui_rhand
		else
			hud.screen_loc = ui_lhand

/obj/item/grab/process()
	if(QDELING(src)) // GC is trying to delete us, we'll kill our processing so we can cleanly GC
		return PROCESS_KILL

	confirm()
	if(!assailant)
		qdel(src) // Same here, except we're trying to delete ourselves.
		return PROCESS_KILL

	if(assailant.client)
		assailant.client.screen -= hud
		assailant.client.screen += hud

	if(assailant.pulling == affecting)
		assailant.stop_pulling()

	if(state <= GRAB_AGGRESSIVE)
		allow_upgrade = 1
		//disallow upgrading if we're grabbing more than one person
		if((assailant.l_hand && assailant.l_hand != src && istype(assailant.l_hand, /obj/item/grab)))
			var/obj/item/grab/G = assailant.l_hand
			if(G.affecting != affecting)
				allow_upgrade = 0
		if((assailant.r_hand && assailant.r_hand != src && istype(assailant.r_hand, /obj/item/grab)))
			var/obj/item/grab/G = assailant.r_hand
			if(G.affecting != affecting)
				allow_upgrade = 0

		//disallow upgrading past aggressive if we're being grabbed aggressively
		for(var/obj/item/grab/G in affecting.grabbed_by)
			if(G == src) continue
			if(G.state >= GRAB_AGGRESSIVE)
				allow_upgrade = 0

		if(allow_upgrade)
			if(state < GRAB_AGGRESSIVE)
				hud.icon_state = "reinforce"
			else
				hud.icon_state = "reinforce1"
		else
			hud.icon_state = "!reinforce"

	if(state >= GRAB_AGGRESSIVE)
		affecting.drop_l_hand()
		affecting.drop_r_hand()

		if(iscarbon(affecting))
			handle_eye_mouth_covering(affecting, assailant, assailant.zone_sel.selecting)

		if(force_down)
			if(affecting.loc != assailant.loc)
				force_down = 0
			else
				affecting.Weaken(2)

	if(state >= GRAB_NECK)
		affecting.Stun(3)
		if(isliving(affecting))
			var/mob/living/L = affecting
			L.adjustOxyLoss(1)

	if(state >= GRAB_KILL)
		//affecting.apply_effect(STUTTER, 5) //would do this, but affecting isn't declared as mob/living for some stupid reason.
		affecting.stuttering = max(affecting.stuttering, 5) //It will hamper your voice, being choked and all.
		affecting.Weaken(5)	//Should keep you down unless you get help.
		if(ishuman(affecting))
			var/mob/living/carbon/human/A = affecting
			if (!(A.species.flags & NO_BREATHE))
				A.losebreath = max(A.losebreath + 2, 3)

	adjust_position()

/obj/item/grab/proc/handle_eye_mouth_covering(mob/living/carbon/target, mob/user, var/target_zone)
	var/announce = (target_zone != last_hit_zone) //only display messages when switching between different target zones
	last_hit_zone = target_zone

	switch(target_zone)
		if("mouth")
			if(announce)
				user.visible_message("<span class='warning'>\The [user] covers [target]'s face!</span>")
			if(target.silent < 3)
				target.silent = 3
		if(BP_EYES)
			if(announce)
				assailant.visible_message("<span class='warning'>[assailant] covers [affecting]'s eyes!</span>")
			if(affecting.eye_blind < 3)
				affecting.eye_blind = 3

/obj/item/grab/attack_self()
	return s_click(hud)


//Updating pixelshift, position and direction
//Gets called on process, when the grab gets upgraded or the assailant moves
/obj/item/grab/proc/adjust_position()
	if (!affecting)
		return
	if(affecting.buckled)
		animate(affecting, pixel_x = 0, pixel_y = 0, 4, 1, LINEAR_EASING)
		return
	if(affecting.lying && state != GRAB_KILL)
		animate(affecting, pixel_x = 0, pixel_y = 0, 5, 1, LINEAR_EASING)
		if(force_down)
			affecting.set_dir(SOUTH) //face up
		return
	var/shift = 0
	var/adir = get_dir(assailant, affecting)
	affecting.layer = 4
	switch(state)
		if(GRAB_PASSIVE)
			shift = 8
			if(dancing) //look at partner
				shift = 10
				assailant.set_dir(get_dir(assailant, affecting))
		if(GRAB_AGGRESSIVE)
			shift = 12
		if(GRAB_NECK, GRAB_UPGRADING)
			shift = -10
			adir = assailant.dir
			affecting.set_dir(assailant.dir)
			affecting.forceMove(assailant.loc)
		if(GRAB_KILL)
			shift = 0
			adir = 1
			affecting.set_dir(SOUTH) //face up
			affecting.forceMove(assailant.loc)

	switch(adir)
		if(NORTH)
			animate(affecting, pixel_x = 0, pixel_y =-shift, 5, 1, LINEAR_EASING)
			affecting.layer = 3.9
		if(SOUTH)
			animate(affecting, pixel_x = 0, pixel_y = shift, 5, 1, LINEAR_EASING)
		if(WEST)
			animate(affecting, pixel_x = shift, pixel_y = 0, 5, 1, LINEAR_EASING)
		if(EAST)
			animate(affecting, pixel_x =-shift, pixel_y = 0, 5, 1, LINEAR_EASING)

/obj/item/grab/proc/s_click(obj/screen/S)
	if(!affecting)
		return
	if(state == GRAB_UPGRADING)
		return
	if(!assailant.canClick())
		return
	if(!assailant.canmove || assailant.lying)
		qdel(src)
		return

	var/grab_coeff = 1
	if(ishuman(affecting))
		var/mob/living/carbon/human/H = affecting
		if(H.species)
			grab_coeff = H.species.grab_mod

	if(world.time < (last_action + (UPGRADE_COOLDOWN * grab_coeff)))
		return

	last_action = world.time

	if(state < GRAB_AGGRESSIVE)
		if(!allow_upgrade)
			return
		if(!affecting.lying)
			assailant.visible_message("<span class='warning'>[assailant] has grabbed [affecting] aggressively (now hands)!</span>")
		else
			assailant.visible_message("<span class='warning'>[assailant] pins [affecting] down to the ground (now hands)!</span>")
			apply_pinning(affecting, assailant)

		state = GRAB_AGGRESSIVE
		icon_state = "grabbed1"
		hud.icon_state = "reinforce1"
	else if(state < GRAB_NECK)
		if(isslime(affecting))
			to_chat(assailant, "<span class='notice'>You squeeze [affecting], but nothing interesting happens.</span>")
			return

		assailant.visible_message("<span class='warning'>[assailant] has reinforced \his grip on [affecting] (now neck)!</span>")
		state = GRAB_NECK
		icon_state = "grabbed+1"
		assailant.set_dir(get_dir(assailant, affecting))
		affecting.attack_log += "\[[time_stamp()]\] <font color='orange'>Has had their neck grabbed by [assailant.name] ([assailant.ckey])</font>"
		assailant.attack_log += "\[[time_stamp()]\] <font color='red'>Grabbed the neck of [affecting.name] ([affecting.ckey])</font>"
		msg_admin_attack("[key_name_admin(assailant)] grabbed the neck of [key_name_admin(affecting)]",ckey=key_name(assailant),ckey_target=key_name(affecting))
		hud.icon_state = "kill"
		hud.name = "kill"
		affecting.Stun(10) //10 ticks of ensured grab
	else if(state < GRAB_UPGRADING)
		assailant.visible_message("<span class='danger'>[assailant] starts to tighten \his grip on [affecting]'s neck!</span>")
		hud.icon_state = "kill1"

		state = GRAB_KILL
		assailant.visible_message("<span class='danger'>[assailant] has tightened \his grip on [affecting]'s neck!</span>")
		affecting.attack_log += "\[[time_stamp()]\] <font color='orange'>Has been strangled (kill intent) by [assailant.name] ([assailant.ckey])</font>"
		assailant.attack_log += "\[[time_stamp()]\] <font color='red'>Strangled (kill intent) [affecting.name] ([affecting.ckey])</font>"
		msg_admin_attack("[key_name_admin(assailant)] strangled (kill intent) [key_name_admin(affecting)]",ckey=key_name(assailant),ckey_target=key_name(affecting))

		affecting.setClickCooldown(10)
		if(ishuman(affecting))
			var/mob/living/carbon/human/A = affecting
			if (!(A.species.flags & NO_BREATHE))
				A.losebreath += 1
		affecting.set_dir(WEST)
	adjust_position()

//This is used to make sure the victim hasn't managed to yackety sax away before using the grab.
/obj/item/grab/proc/confirm()
	if(!assailant || !affecting)
		qdel(src)
		return 0

	if(affecting)
		if(!isturf(assailant.loc) || ( !isturf(affecting.loc) || assailant.loc != affecting.loc && get_dist(assailant, affecting) > 1) || assailant.z != affecting.z )
			qdel(src)
			return 0

	return 1

/obj/item/grab/attack(mob/M, mob/living/user, var/target_zone)
	if(!affecting)
		return
	if(world.time < (last_action + 20))
		return

	last_action = world.time
	reset_kill_state() //using special grab moves will interrupt choking them

	//clicking on the victim while grabbing them
	if(M == affecting)
		if(ishuman(affecting))
			var/hit_zone = target_zone
			flick(hud.icon_state, hud)
			switch(assailant.a_intent)
				if(I_HELP)
					if(force_down)
						to_chat(assailant, "<span class='warning'>You are no longer pinning [affecting] to the ground.</span>")
						force_down = 0
						return
					inspect_organ(affecting, assailant, hit_zone)

				if(I_GRAB)
					jointlock(affecting, assailant, hit_zone)

				if(I_HURT)
					if(hit_zone == BP_EYES)
						attack_eye(affecting, assailant)
					else if(hit_zone == BP_HEAD)
						headbut(affecting, assailant)
					else
						dislocate(affecting, assailant, hit_zone)

				if(I_DISARM)
					if(hit_zone != BP_HEAD)
						pin_down(affecting, assailant)
					if(hit_zone == BP_HEAD)
						hair_pull(affecting, assailant)

	//clicking on yourself while grabbing them
	if(M == assailant && state >= GRAB_AGGRESSIVE)
		devour(affecting, assailant)

/obj/item/grab/dropped()
	loc = null
	if(!destroying)
		qdel(src)

/obj/item/grab/proc/reset_kill_state()
	if(state == GRAB_KILL)
		assailant.visible_message("<span class='warning'>[assailant] lost \his tight grip on [affecting]'s neck!</span>")
		hud.icon_state = "kill"
		state = GRAB_NECK

/obj/item/grab
	var/destroying = 0

/obj/item/grab/Destroy()
	animate(affecting, pixel_x = 0, pixel_y = 0, 4, 1, LINEAR_EASING)
	affecting.layer = 4
	if(affecting)
		ADD_FALLING_ATOM(affecting) // Makes the grabbee check if they can fall.
		affecting.grabbed_by -= src
		affecting = null
	if(assailant)
		if(assailant.client)
			assailant.client.screen -= hud
		assailant = null
	qdel(hud)
	hud = null
	destroying = 1 // stops us calling qdel(src) on dropped()
	return ..()
