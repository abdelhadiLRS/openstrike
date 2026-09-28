

// make attachments points for muzzleflash effects -- these should be overwritten by the attachments in the models, however
$attachment 0 "Bip01 R Hand" 10.855 -0.416715 1.87068
$attachment 1 "Bip01 L Hand" 10.855 -0.416715 1.87068



$gamma 1.6

// set hitboxes
// nb these are old HL values, may need tweaking

$hbox 3 "Bip01 Pelvis" -4.69 -4.44 -6.75  4.00 5.56 6.75
$hbox 6 "Bip01 L Thigh" 2.66 -3.69 -3.09  18.16 4.88 3.31
$hbox 6 "Bip01 L Calf" 0.38 -3.97 -2.84  17.60 4.00 2.94
$hbox 6 "Bip01 L Foot" .85 -3.24 -2.64 5.73 8.53 3.17
$hbox 7 "Bip01 R Thigh" 2.47 -3.69 -3.16  18.13 4.88 3.38
$hbox 7 "Bip01 R Calf" 0.31 -3.97 -2.84  17.60 3.94 2.97
$hbox 7 "Bip01 R Foot" .85 -3.24 -2.64 5.73 8.53 3.17
$hbox 3 "Bip01 Spine1" -3.25 -5.50 -5.50  4.83 5.50 5.50
$hbox 2 "Bip01 Spine2" -0.06 -5.53 -7.59  8.00 7.00 7.59
$hbox 2 "Bip01 Spine3" -2.25 -6.81 -6.31  6.50 5.09 6.31
$hbox 2 "Bip01 Neck" -3.11 -1.50 -3.00  2.05 3.50 3.00
$hbox 1 "Bip01 Head" -.33 -4.5 -2.5 8 4.5 2.5
$hbox 4 "Bip01 L Clavicle" 0.94 -2.88 -4.13  5.44 4.28 3.50
$hbox 4 "Bip01 L UpperArm" -2.16 -2.34 -2.56  11.56 3.41 2.38
$hbox 4 "Bip01 L Forearm" 0.59 -1.81 -2.19  10.75 2.84 2.41
$hbox 4 "Bip01 L Hand" -0.132201 -1.90302 -2.23853 4.8629 2.07824 2.36979
$hbox 5 "Bip01 R Clavicle" 1.38 -2.84 -3.56  5.69 4.31 4.31
$hbox 5 "Bip01 R UpperArm" -1.88 -2.47 -2.16  11.81 3.28 2.81
$hbox 5 "Bip01 R Forearm" 0.44 -1.97 -2.34  10.59 2.72 2.22
$hbox 5 "Bip01 R Hand"  -0.132201 -1.90302 -2.23853 4.8629 2.07824 2.36979

$origin 0 0 36

//dummy that fixes the "idle 0" problem
$sequence dummy  "../animations/tread water" loop fps 24 

// idle poses
$sequence idle1	"..\animations\relaxed stand idle" fps 15 loop 	ACT_IDLE 1

// crouch idles
$sequence crouch_idle 	"..\animations\slow crouch idle" fps 10 loop ACT_CROUCHIDLE 1 origin 0 0 18 	

// basic movements
$sequence walk "..\animations\cs walk (legs only)" fps 30 LX loop ACT_WALK 1 
$sequence run "..\animations\cs run (60 fps)" LX fps 60 loop ACT_RUN 1
$sequence crouchrun "..\animations\cs crouch (legs only)" fps 30 loop LX ACT_CROUCH 1 origin 0 0 18
$sequence jump	"..\animations\jump" fps 30 ACT_HOP 1
$sequence longjump "..\animations\jump" fps 30 ACT_LEAP 1
$sequence swim "../animations/swim" loop fps 30 ACT_SWIM 1 origin 0 0 0
$sequence treadwater "../animations/tread water" loop fps 24 ACT_HOVER 1

// AK47, carbine, rifle, dualpistols, grenade, m249, shotgun, c4,knife

// blended looks

// Aug, ump & p90
$include "animations\carbine.qc"

// pistols
$include "animations\pistols.qc"

// dual pistols
$include "animations\dualpistols.qc"

// long gun
$include "animations\rifle.qc"

//SMG's
$include "animations\mp5.qc"

// Shotguns
$include "animations\shotgun.qc"

// machinegun, low guns
$include "animations\m249.qc"

// grenades
$include "animations\grenade.qc"

// bombs
$include "animations\c4.qc"

// dual pistols
$include "animations\dualpistols.qc"

//knife
$include "animations\knife.qc"

//AK47 -- in final version this is moved to individual models!
$include "animations\Ak47CT.qc"


// flinches

$include "animations\flinches.qc"

//deaths

$sequence death1 	"..\animations\deaths\simple" 	fps 30 	ACT_DIE_CHESTSHOT 1 	{ event 2001 1 }
$sequence death2 	"..\animations\deaths\simple2" 	fps 30 	ACT_DIESIMPLE 2	 	{ event 2001 1 }
$sequence death3 	"..\animations\deaths\simple3" 	fps 30 	ACT_DIE_BACKSHOT 1 	{ event 2001 1 }
$sequence head 	"..\animations\deaths\headshot" 	fps 30 	ACT_DIE_HEADSHOT 1 	{ event 2001 1 }
$sequence gutshot "..\animations\deaths\gut"		fps 30 	ACT_DIE_GUTSHOT 1 	{ event 2001 1 }
$sequence left 	"..\animations\deaths\fall_Left"	fps 30 	ACT_DIESIMPLE 1 		{ event 2001 1 }
$sequence back 	"..\animations\deaths\fall_back" 	fps 30 	ACT_DIEBACKWARD 1 	{ event 2001 1 }
$sequence right 	"..\animations\deaths\fall_right" 	fps 30 	ACT_DIESIMPLE 1 		{ event 2001 1 }
$sequence forward "..\animations\deaths\fall_forward" 	fps 30 	ACT_DIEFORWARD 1		{ event 2001 1 }
$sequence crouch_die "..\animations\deaths\crouch_die"	fps 30	origin 0 0 18	{ event 2001 1 }