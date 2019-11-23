/obj/vehicle/hoverscooter
	name = "hoverscooter"
	desc = "Forward, my trusty steed!"
	icon = 'icons/obj/bike.dmi'
	icon_state = "hoverscooter"
	dir = SOUTH

	load_item_visible = 1
	mob_offset_y = 7
	health = 100
	maxhealth = 100

	fire_dam_coeff = 0.6
	brute_dam_coeff = 0.5

	var/speed = 2
	var/bike_icon = "hoverscooter"

	var/datum/effect_system/ion_trail/ion
	var/kickstand = 1

/obj/vehicle/hoverscooter/Initialize()
	. = ..()
	ion = new(src)
	turn_off()
	add_overlay(image('icons/obj/bike.dmi', "[icon_state]_off_overlay", MOB_LAYER + 1))
	icon_state = "[bike_icon]_off"

/obj/vehicle/hoverscooter/verb/toggle()
	set name = "Toggle Engine"
	set category = "Vehicle"
	set src in view(0)

	if(usr.incapacitated()) return

	if(!on)
		turn_on()
		src.visible_message("\The [src] rumbles to life.", "You hear something rumble deeply.")
		playsound(src, 'sound/misc/bike_start.ogg', 100, 1)
	else
		turn_off()
		src.visible_message("\The [src] putters before turning off.", "You hear something putter slowly.")

/obj/vehicle/hoverscooter/load(var/atom/movable/C)
	var/mob/living/M = C
	if(!istype(C)) return 0
	if(M.buckled || M.restrained() || !Adjacent(M) || !M.Adjacent(src))
		return 0
	return ..(M)

/obj/vehicle/hoverscooter/MouseDrop_T(var/atom/movable/C, mob/user as mob)
	if(!load(C))
		to_chat(user, "<span class='warning'>You were unable to load \the [C] onto \the [src].</span>")
		return

/obj/vehicle/hoverscooter/attack_hand(var/mob/user as mob)
	if(user == load)
		unload(load)
		to_chat(user, "You unbuckle yourself from \the [src]")
	else if(user != load && load)
		user.visible_message ("[user] starts to unbuckle [load] from \the [src]!")
		if(do_after(user, 8 SECONDS, act_target = src))
			unload(load)
			to_chat(user, "You unbuckle [load] from \the [src]")
			to_chat(load, "You were unbuckled from \the [src] by [user]")

/obj/vehicle/hoverscooter/relaymove(mob/user, direction)
	if(user != load || !on || user.incapacitated())
		return
	return Move(get_step(src, direction))

/obj/vehicle/hoverscooter/Move(var/turf/destination)
	move_delay = speed
	return ..()

/obj/vehicle/hoverscooter/turn_on()
	ion.start()
	anchored = 1

	update_icon()

	if(pulledby)
		pulledby.stop_pulling()
	..()

/obj/vehicle/hoverscooter/turn_off()
	ion.stop()
	anchored = kickstand

	update_icon()

	..()

/obj/vehicle/hoverscooter/update_icon()
	cut_overlays()

	if(on)
		add_overlay(image('icons/obj/bike.dmi', "[bike_icon]_on_overlay", MOB_LAYER + 1))
		icon_state = "[bike_icon]_on"
	else
		add_overlay(image('icons/obj/bike.dmi', "[bike_icon]_off_overlay", MOB_LAYER + 1))
		icon_state = "[bike_icon]_off"

	..()

/obj/vehicle/hoverscooter/Destroy()
	QDEL_NULL(ion)

	return ..()