$sequence crouch_aim_carbine "..\animations\crouchlooks\carbine\LU" {
	"..\animations\crouchlooks\carbine\U"
	"..\animations\crouchlooks\carbine\RU"	
	"..\animations\crouchlooks\carbine\L"
	"..\animations\crouchlooks\carbine\crouchlook"
	"..\animations\crouchlooks\carbine\R"	
	"..\animations\crouchlooks\carbine\LD"
	"..\animations\crouchlooks\carbine\D"
	"..\animations\crouchlooks\carbine\RD"	
 	blend XR -90 90 loop
	frames 0 1
	origin 0 0 18
	}


$sequence crouch_shoot_carbine "..\animations\crouchfires\carbine\LU" {
	"..\animations\crouchfires\carbine\U"
	"..\animations\crouchfires\carbine\RU"	
	"..\animations\crouchfires\carbine\L"
	"..\animations\crouchfires\carbine\crouchfire"
	"..\animations\crouchfires\carbine\R"	
	"..\animations\crouchfires\carbine\LD"
	"..\animations\crouchfires\carbine\D"
	"..\animations\crouchfires\carbine\RD"	
	blend XR -90 90
	fps 15
	event 5001 0 "40"
	origin 0 0 18
	}

$sequence crouch_reload_carbine "..\animations\reloads\carbine"  origin 0 0 18

$sequence ref_aim_carbine "..\animations\looks\carbine\LU" {
	"..\animations\looks\carbine\U"
	"..\animations\looks\carbine\RU"	
	"..\animations\looks\carbine\L"
	"..\animations\looks\carbine\look"
	"..\animations\looks\carbine\R"	
	"..\animations\looks\carbine\LD"
	"..\animations\looks\carbine\D"
	"..\animations\looks\carbine\RD"	
 	blend XR -90 90 loop
	frames 0 1
	}	

$sequence ref_shoot_carbine "..\animations\fires\carbine\LU" {
	"..\animations\fires\carbine\U" 
	"..\animations\fires\carbine\RU" 
	"..\animations\fires\carbine\L" 
	"..\animations\fires\carbine\fire" 
	"..\animations\fires\carbine\R" 
	"..\animations\fires\carbine\LD" 
	"..\animations\fires\carbine\D" 
	"..\animations\fires\carbine\RD" 
	blend XR -90 90
	fps 15
	event 5001 0 "40"
	}

$sequence ref_reload_carbine "..\animations\reloads\carbine"   