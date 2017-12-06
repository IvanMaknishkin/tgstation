/obj/machinery/computer/camera_advanced/shuttle_docker
	name = "navigation computer"
	desc = "Used to designate a precise transit location for a spacecraft."
	jump_action = null
	var/datum/action/innate/shuttledocker_rotate/rotate_action = new
	var/datum/action/innate/shuttledocker_place/place_action = new
	var/shuttleId = ""
	var/shuttlePortId = ""
	var/shuttlePortName = ""
	var/list/jumpto_ports = list() //hashset of ports to jump to and ignore for collision purposes
	var/obj/docking_port/stationary/my_port //the custom docking port placed by this console
	var/obj/docking_port/mobile/shuttle_port //the mobile docking port of the connected shuttle
	var/view_range = 7
	var/x_offset = 0
	var/y_offset = 0
	var/space_turfs_only = TRUE

/obj/machinery/computer/camera_advanced/shuttle_docker/GrantActions(mob/living/user)
	if(jumpto_ports.len)
		jump_action = new /datum/action/innate/camera_jump/shuttle_docker
	..()

	if(rotate_action)
		rotate_action.target = user
		rotate_action.Grant(user)
		actions += rotate_action

	if(place_action)
		place_action.target = user
		place_action.Grant(user)
		actions += place_action

/obj/machinery/computer/camera_advanced/shuttle_docker/CreateEye()
	shuttle_port = SSshuttle.getShuttle(shuttleId)
	if(QDELETED(shuttle_port))
		shuttle_port = null
		return

	eyeobj = new /mob/camera/aiEye/remote/shuttle_docker()
	var/mob/camera/aiEye/remote/shuttle_docker/the_eye = eyeobj
	the_eye.origin = src
	the_eye.dir = shuttle_port.dir
	var/turf/origin = locate(shuttle_port.x + x_offset, shuttle_port.y + y_offset, shuttle_port.z)
	for(var/V in shuttle_port.shuttle_areas)
		var/area/A = V
		for(var/turf/T in A)
			if(T.z != origin.z)
				continue
			var/image/I = image('icons/effects/alphacolors.dmi', origin, "red")
			var/x_off = T.x - origin.x
			var/y_off = T.y - origin.y
			I.loc = locate(origin.x + x_off, origin.y + y_off, origin.z) //we have to set this after creating the image because it might be null, and images created in nullspace are immutable.
			I.layer = ABOVE_NORMAL_TURF_LAYER
			I.plane = 0
			I.mouse_opacity = 0
			the_eye.placement_images[I] = list(x_off, y_off)

/obj/machinery/computer/camera_advanced/shuttle_docker/give_eye_control(mob/user)
	..()
	if(!QDELETED(user) && user.client)
		var/mob/camera/aiEye/remote/shuttle_docker/the_eye = eyeobj
		user.client.images += the_eye.placement_images
		user.client.images += the_eye.placed_images
		user.client.change_view(view_range)

/obj/machinery/computer/camera_advanced/shuttle_docker/remove_eye_control(mob/living/user)
	..()
	if(!QDELETED(user) && user.client)
		var/mob/camera/aiEye/remote/shuttle_docker/the_eye = eyeobj
		user.client.images -= the_eye.placement_images
		user.client.images -= the_eye.placed_images
		user.client.change_view(CONFIG_GET(string/default_view))

/obj/machinery/computer/camera_advanced/shuttle_docker/proc/placeLandingSpot()
	if(!checkLandingSpot())
		return FALSE
	var/mob/camera/aiEye/remote/shuttle_docker/the_eye = eyeobj
	if(!my_port)
		my_port = new /obj/docking_port/stationary()
		my_port.name = shuttlePortName
		my_port.id = shuttlePortId
		var/obj/docking_port/mobile/M = SSshuttle.getShuttle(shuttleId)
		my_port.height = M.height
		my_port.width = M.width
		my_port.dheight = M.dheight
		my_port.dwidth = M.dwidth
	my_port.dir = the_eye.dir
	my_port.loc = locate(eyeobj.x - x_offset, eyeobj.y - y_offset, eyeobj.z)
	if(current_user && current_user.client)
		current_user.client.images -= the_eye.placed_images

	for(var/V in the_eye.placed_images)
		qdel(V)
	the_eye.placed_images = list()

	for(var/V in the_eye.placement_images)
		var/image/I = V
		var/image/newI = image('icons/effects/alphacolors.dmi', the_eye.loc, "blue")
		newI.loc = I.loc //It is highly unlikely that any landing spot including a null tile will get this far, but better safe than sorry
		newI.layer = ABOVE_OPEN_TURF_LAYER
		newI.plane = 0
		newI.mouse_opacity = 0
		the_eye.placed_images += newI

	if(current_user && current_user.client)
		current_user.client.images += the_eye.placed_images
	return TRUE

/obj/machinery/computer/camera_advanced/shuttle_docker/proc/rotateLandingSpot()
	var/mob/camera/aiEye/remote/shuttle_docker/the_eye = eyeobj
	var/list/image_cache = the_eye.placement_images
	the_eye.dir = turn(the_eye.dir, -90)
	for(var/i in 1 to image_cache.len)
		var/image/pic = image_cache[i]
		var/list/coords = image_cache[pic]
		var/Tmp = coords[1]
		coords[1] = coords[2]
		coords[2] = -Tmp
		pic.loc = locate(the_eye.x + coords[1], the_eye.y + coords[2], the_eye.z)
	var/Tmp = x_offset
	x_offset = y_offset
	y_offset = -Tmp
	checkLandingSpot()

/obj/machinery/computer/camera_advanced/shuttle_docker/proc/checkLandingSpot()
	var/mob/camera/aiEye/remote/shuttle_docker/the_eye = eyeobj
	var/turf/eyeturf = get_turf(the_eye)
	if(!eyeturf)
		return
	var/list/bounds = shuttle_port.return_coords(the_eye.x - x_offset, the_eye.y - y_offset, the_eye.dir)
	var/list/overlappers = SSshuttle.get_dock_overlap(bounds[1], bounds[2], bounds[3], bounds[4], the_eye.z)
	. = TRUE
	var/list/image_cache = the_eye.placement_images
	for(var/i in 1 to image_cache.len)
		var/image/I = image_cache[i]
		var/list/coords = image_cache[I]
		var/turf/T = locate(eyeturf.x + coords[1], eyeturf.y + coords[2], eyeturf.z)
		I.loc = T
		if(checkLandingTurf(T, overlappers))
			I.icon_state = "green"
		else
			I.icon_state = "red"
			. = FALSE

/obj/machinery/computer/camera_advanced/shuttle_docker/proc/checkLandingTurf(turf/T, list/overlappers)
	// Too close to the map edge is never allowed
	if(!T || T.x == 1 || T.y == 1 || T.x == world.maxx || T.y == world.maxy)
		return FALSE
	// If it's one of our shuttle areas assume it's ok to be there
	if(shuttle_port.shuttle_areas[T.loc])
		return TRUE
	// Checking for overlapping dock boundaries
	for(var/i in 1 to overlappers.len)
		var/obj/docking_port/port = overlappers[i]
		if(port == my_port)
			continue
		var/list/overlap = overlappers[port]
		var/list/xs = overlap[1]
		var/list/ys = overlap[2]
		if(xs["[T.x]"] && ys["[T.y]"])
			return FALSE
	if(space_turfs_only && !isspaceturf(T))
		return FALSE
	return TRUE

/mob/camera/aiEye/remote/shuttle_docker
	visible_icon = FALSE
	use_static = FALSE
	var/list/placement_images = list()
	var/list/placed_images = list()

/mob/camera/aiEye/remote/shuttle_docker/setLoc(T)
	..()
	var/obj/machinery/computer/camera_advanced/shuttle_docker/console = origin
	console.checkLandingSpot()

/mob/camera/aiEye/remote/shuttle_docker/update_remote_sight(mob/living/user)
	user.sight = BLIND|SEE_TURFS
	user.lighting_alpha = LIGHTING_PLANE_ALPHA_INVISIBLE
	user.sync_lighting_plane_alpha()
	return TRUE

/datum/action/innate/shuttledocker_rotate
	name = "Rotate"
	icon_icon = 'icons/mob/actions/actions_mecha.dmi'
	button_icon_state = "mech_cycle_equip_off"

/datum/action/innate/shuttledocker_rotate/Activate()
	if(QDELETED(target) || !isliving(target))
		return
	var/mob/living/C = target
	var/mob/camera/aiEye/remote/remote_eye = C.remote_control
	var/obj/machinery/computer/camera_advanced/shuttle_docker/origin = remote_eye.origin
	origin.rotateLandingSpot()

/datum/action/innate/shuttledocker_place
	name = "Place"
	icon_icon = 'icons/mob/actions/actions_mecha.dmi'
	button_icon_state = "mech_zoom_off"

/datum/action/innate/shuttledocker_place/Activate()
	if(QDELETED(target) || !isliving(target))
		return
	var/mob/living/C = target
	var/mob/camera/aiEye/remote/remote_eye = C.remote_control
	var/obj/machinery/computer/camera_advanced/shuttle_docker/origin = remote_eye.origin
	if(origin.placeLandingSpot())
		to_chat(target, "<span class='notice'>Transit location designated</span>")
	else
		to_chat(target, "<span class='warning'>Invalid transit location</span>")

/datum/action/innate/camera_jump/shuttle_docker
	name = "Jump to Location"
	button_icon_state = "camera_jump"

/datum/action/innate/camera_jump/shuttle_docker/Activate()
	if(QDELETED(target) || !isliving(target))
		return
	var/mob/living/C = target
	var/mob/camera/aiEye/remote/remote_eye = C.remote_control
	var/obj/machinery/computer/camera_advanced/shuttle_docker/console = remote_eye.origin

	playsound(console, 'sound/machines/terminal_prompt_deny.ogg', 25, 0)

	var/list/L = list()
	for(var/V in SSshuttle.stationary)
		if(!V)
			continue
		var/obj/docking_port/stationary/S = V
		if(console.z_lock.len && !(S.z in console.z_lock))
			continue
		if(console.jumpto_ports[S.id])
			L[S.name] = S

	playsound(console, 'sound/machines/terminal_prompt.ogg', 25, 0)
	var/selected = input("Choose location to jump to", "Locations", null) as null|anything in L
	if(QDELETED(src) || QDELETED(target) || !isliving(target))
		return
	playsound(src, "terminal_type", 25, 0)
	if(selected)
		var/turf/T = get_turf(L[selected])
		if(T)
			playsound(console, 'sound/machines/terminal_prompt_confirm.ogg', 25, 0)
			remote_eye.setLoc(T)
			to_chat(target, "<span class='notice'>Jumped to [selected]</span>")
			C.overlay_fullscreen("flash", /obj/screen/fullscreen/flash/static)
			C.clear_fullscreen("flash", 3)
	else
		playsound(console, 'sound/machines/terminal_prompt_deny.ogg', 25, 0)
