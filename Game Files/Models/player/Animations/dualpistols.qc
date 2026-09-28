$sequence crouch_aim_dualpistols "..\animations\crouchlooks\dualpistols\LU" {
	"..\animations\crouchlooks\dualpistols\U"
	"..\animations\crouchlooks\dualpistols\RU"	
	"..\animations\crouchlooks\dualpistols\L"
	"..\animations\crouchlooks\dualpistols\crouchlook"
	"..\animations\crouchlooks\dualpistols\R"	
	"..\animations\crouchlooks\dualpistols\LD"
	"..\animations\crouchlooks\dualpistols\D"
	"..\animations\crouchlooks\dualpistols\RD"	
 	blend XR -90 90 loop
	fps 10
	origin 0 0 18
	}

// left hand shoot
$sequence crouch_shoot_dualpistols "..\animations\crouchfires\dualpistols\left\LU" {
	"..\animations\crouchfires\dualpistols\left\U"
	"..\animations\crouchfires\dualpistols\left\RU"	
	"..\animations\crouchfires\dualpistols\left\L"
	"..\animations\crouchfires\dualpistols\left\crouchfire"
	"..\animations\crouchfires\dualpistols\left\R"	
	"..\animations\crouchfires\dualpistols\left\LD"
	"..\animations\crouchfires\dualpistols\left\D"
	"..\animations\crouchfires\dualpistols\left\RD"	
	blend XR -90 90
	fps 30
	event 5011 0 "10"
	origin 0 0 18
	}
//right
$sequence crouch_shoot2_dualpistols "..\animations\crouchfires\dualpistols\right\LU" {
	"..\animations\crouchfires\dualpistols\right\U"
	"..\animations\crouchfires\dualpistols\right\RU"	
	"..\animations\crouchfires\dualpistols\right\L"
	"..\animations\crouchfires\dualpistols\right\crouchfire"
	"..\animations\crouchfires\dualpistols\right\R"	
	"..\animations\crouchfires\dualpistols\right\LD"
	"..\animations\crouchfires\dualpistols\right\D"
	"..\animations\crouchfires\dualpistols\right\RD"	
	blend XR -90 90
	fps 30
	event 5001 0 "10"
	origin 0 0 18
	}

$sequence crouch_reload_dualpistols "..\animations\reloads\dualpistols" origin 0 0 18

$sequence ref_aim_dualpistols "..\animations\looks\dualpistols\LU" {
	"..\animations\looks\dualpistols\U"
	"..\animations\looks\dualpistols\RU"	
	"..\animations\looks\dualpistols\L"
	"..\animations\looks\dualpistols\look"
	"..\animations\looks\dualpistols\R"	
	"..\animations\looks\dualpistols\LD"
	"..\animations\looks\dualpistols\D"
	"..\animations\looks\dualpistols\RD"	
 	blend XR -90 90 loop
	fps 10
	}	
// left
$sequence ref_shoot_dualpistols "..\animations\fires\dualpistols\left\LU" {
	"..\animations\fires\dualpistols\left\U" 
	"..\animations\fires\dualpistols\left\RU" 
	"..\animations\fires\dualpistols\left\L" 
	"..\animations\fires\dualpistols\left\fire" 
	"..\animations\fires\dualpistols\left\R" 
	"..\animations\fires\dualpistols\left\LD" 
	"..\animations\fires\dualpistols\left\D" 
	"..\animations\fires\dualpistols\left\RD" 
	blend XR -90 90
	fps 30
	event 5011 0 "10"
	}
//right
$sequence ref_shoot2_dualpistols "..\animations\fires\dualpistols\right\LU" {
	"..\animations\fires\dualpistols\right\U" 
	"..\animations\fires\dualpistols\right\RU" 
	"..\animations\fires\dualpistols\right\L" 
	"..\animations\fires\dualpistols\right\fire" 
	"..\animations\fires\dualpistols\right\R" 
	"..\animations\fires\dualpistols\right\LD" 
	"..\animations\fires\dualpistols\right\D" 
	"..\animations\fires\dualpistols\right\RD" 
	blend XR -90 90
	fps 30
	event 5001 0 "10"
	}
$sequence ref_reload_dualpistols "..\animations\reloads\dualpistols" 