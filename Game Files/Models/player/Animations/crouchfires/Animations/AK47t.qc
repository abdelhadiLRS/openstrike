$sequence crouch_aim_ak47 "..\animations\crouchlooks\mp5\LU" {
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


$sequence crouch_shoot_ak47 "..\animations\crouchfires\mp5\LU" {
	"..\animations\crouchfires\mp5\U"
	"..\animations\crouchfires\mp5\RU"	
	"..\animations\crouchfires\mp5\L"
	"..\animations\crouchfires\mp5\crouchfire"
	"..\animations\crouchfires\mp5\R"	
	"..\animations\crouchfires\mp5\LD"
	"..\animations\crouchfires\mp5\D"
	"..\animations\crouchfires\mp5\RD"	
	blend XR -90 90
	fps 30
	origin 0 0 18
	frames 0 5
	event 5001 0 "40"
	}

$sequence crouch_reload_ak47 "..\animations\reloads\AR" origin 0 0 18

$sequence ref_aim_ak47 "..\animations\looks\ak47\LU" {
	"..\animations\looks\ak47\U"
	"..\animations\looks\ak47\RU"	
	"..\animations\looks\ak47\L"
	"..\animations\looks\ak47\look"
	"..\animations\looks\ak47\R"	
	"..\animations\looks\ak47\LD"
	"..\animations\looks\ak47\D"
	"..\animations\looks\ak47\RD"	
 	blend XR -90 90 loop
	frames 0 1
	}	

$sequence ref_shoot_ak47 "..\animations\fires\ak47\LU" {
	"..\animations\fires\ak47\U" 
	"..\animations\fires\ak47\RU" 
	"..\animations\fires\ak47\L" 
	"..\animations\fires\ak47\fire" 
	"..\animations\fires\ak47\R" 
	"..\animations\fires\ak47\LD" 
	"..\animations\fires\ak47\D" 
	"..\animations\fires\ak47\RD" 
	blend XR -90 90
	fps 30
	frames 0 5
	event 5001 0 "40"
	}

$sequence ref_reload_ak47 "..\animations\reloads\AR" 