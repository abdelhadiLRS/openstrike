$sequence crouch_aim_m249 "..\animations\crouchlooks\m249\LU" {
	"..\animations\crouchlooks\m249\U"
	"..\animations\crouchlooks\m249\RU"	
	"..\animations\crouchlooks\m249\L"
	"..\animations\crouchlooks\m249\crouchlook"
	"..\animations\crouchlooks\m249\R"	
	"..\animations\crouchlooks\m249\LD"
	"..\animations\crouchlooks\m249\D"
	"..\animations\crouchlooks\m249\RD"	
 	blend XR -90 90 loop
	fps 10
	origin 0 0 18
	}


$sequence crouch_shoot_m249 "..\animations\crouchfires\m249\LU" {
	"..\animations\crouchfires\m249\U"
	"..\animations\crouchfires\m249\RU"	
	"..\animations\crouchfires\m249\L"
	"..\animations\crouchfires\m249\crouchfire"
	"..\animations\crouchfires\m249\R"	
	"..\animations\crouchfires\m249\LD"
	"..\animations\crouchfires\m249\D"
	"..\animations\crouchfires\m249\RD"	
 	blend XR -90 90 loop
	fps 30
	frames 0 5
	origin 0 0 18
	event 5001 0 "50"
	}

	

$sequence crouch_reload_m249 "..\animations\reloads\m249" origin 0 0 18

$sequence ref_aim_m249 "..\animations\looks\m249\LU" {
	"..\animations\looks\m249\U"
	"..\animations\looks\m249\RU"	
	"..\animations\looks\m249\L"
	"..\animations\looks\m249\look"
	"..\animations\looks\m249\R"	
	"..\animations\looks\m249\LD"
	"..\animations\looks\m249\D"
	"..\animations\looks\m249\RD"	
 	blend XR -90 90 loop
	fps 10
	}	

$sequence ref_shoot_m249 "..\animations\fires\m249\LU" {
	"..\animations\fires\m249\U"
	"..\animations\fires\m249\RU"	
	"..\animations\fires\m249\L"
	"..\animations\fires\m249\fire"
	"..\animations\fires\m249\R"	
	"..\animations\fires\m249\LD"
	"..\animations\fires\m249\D"
	"..\animations\fires\m249\RD"	
 	blend XR -90 90 loop
	fps 30
	frames 0 5
	event 5001 0 "50"
	}	



$sequence ref_reload_m249 "..\animations\reloads\m249 crouch"  