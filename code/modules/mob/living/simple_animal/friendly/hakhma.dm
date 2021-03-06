/mob/living/simple_animal/hakhma
	name = "hakhma"
	desc = "An oversized insect breed by Scarab colony ships, known for their milk."
	icon = 'icons/mob/npc/livestock.dmi'
	icon_state = "hakhma"
	icon_living = "hakhma"
	icon_dead = "hakhma_dead"
	icon_rest = "hakhma_rest"
	speak_emote = list("chitters")
	emote_hear = list("chitters")
	emote_see = list("shakes its head")
	speak_chance = 1
	turns_per_move = 5
	meat_amount = 35
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	health = 250
	maxHealth = 250

	autoseek_food = FALSE
	beg_for_food = FALSE
	mob_size = 15

	has_udder = TRUE
	milk_type = "beetle_milk"
