$sequence crouch_aim_mp5 "..\animations\crouchlooks\mp5\LU" {
	"..\animations\crouchlooks\mp5\U"
	"..\animations\crouchlooks\mp5\RU"	
	"..\animations\crouchlooks\mp5\L"
	"..\animations\crouchlooks\mp5\crouchlook"
	"..\animations\crouchlooks\mp5\R"	
	"..\animations\crouchlooks\mp5\LD"
	"..\animations\crouchlooks\mp5\D"
	"..\animations\crouchlooks\mp5\RD"	
 	blend XR -90 90 loop
	frames 0 1
	origin 0 0 18	
	}


$sequence crouch_shoot_mp5 "..\animations\crouchfires\mp5\LU" {
	"..\animations\crouchfires\mp5\U"
	"..\animations\crouchfires\mp5\RU"	
	"..\animations\crouchfires\mp5\L"
	"..\animations\crouchfires\mp5\crouchfire"
	"..\animations\crouchfires\mp5\R"	
	"..\animations\crouchfires\mp5\LD"
	"..\animations\crouchfires\mp5\D"
	"..\animations\crouchfires\mp5\RD"	
	blend XR -90 90
	fps 15
	event 5001 0 "30"
	origin 0 0 18
	}

$sequence crouch_reload_mp5 "..\animations\reloads\mp5" origin 0 0 18

$sequence ref_aim_mp5 "..\animations\looks\mp5\LU" {
	"..\animations\looks\mp5\U"
	"..\animations\looks\mp5\RU"	
	"..\animations\looks\mp5\L"
	"..\animations\looks\mp5\look"
	"..\animations\looks\mp5\R"	
	"..\animations\looks\mp5\LD"
	"..\animations\looks\mp5\D"
	"..\animations\looks\mp5\RD"	
 	blend XR -90 90 loop
	frames 0 1
	}	

$sequence ref_shoot_mp5 "..\animations\fires\mp5\LU" {
	"..\animations\fires\mp5\U" 
	"..\animations\fires\mp5\RU" 
	"..\animations\fires\mp5\L" 
	"..\animations\fires\mp5\fire" 
	"..\animations\fires\mp5\R" 
	"..\animations\fires\mp5\LD" 
	"..\animations\fires\mp5\D" 
	"..\animations\fires\mp5\RD" 
	blend XR -90 90
	fps 15
	event 5001 0 "30"
	}

$sequence ref_reload_mp5 "..\animations\reloads\mp5" 