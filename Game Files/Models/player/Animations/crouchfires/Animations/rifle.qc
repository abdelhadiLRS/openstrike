$sequence crouch_aim_rifle "..\animations\crouchlooks\rifle\LU" {
	"..\animations\crouchlooks\rifle\U"
	"..\animations\crouchlooks\rifle\RU"	
	"..\animations\crouchlooks\rifle\L"
	"..\animations\crouchlooks\rifle\crouchlook"
	"..\animations\crouchlooks\rifle\R"	
	"..\animations\crouchlooks\rifle\LD"
	"..\animations\crouchlooks\rifle\D"
	"..\animations\crouchlooks\rifle\RD"	
 	blend XR -90 90 loop
	frames 0 1
	origin 0 0 18
	
	}


$sequence crouch_shoot_rifle "..\animations\crouchfires\rifle\LU" {
	"..\animations\crouchfires\rifle\U"
	"..\animations\crouchfires\rifle\RU"	
	"..\animations\crouchfires\rifle\L"
	"..\animations\crouchfires\rifle\crouchfire"
	"..\animations\crouchfires\rifle\R"	
	"..\animations\crouchfires\rifle\LD"
	"..\animations\crouchfires\rifle\D"
	"..\animations\crouchfires\rifle\RD"	
	blend XR -90 90
	fps 20
	event 5001 0 "30"
	origin 0 0 18
	}

$sequence crouch_reload_rifle "..\animations\reloads\ar"  origin 0 0 18

$sequence ref_aim_rifle "..\animations\looks\rifle\LU" {
	"..\animations\looks\rifle\U"
	"..\animations\looks\rifle\RU"	
	"..\animations\looks\rifle\L"
	"..\animations\looks\rifle\look"
	"..\animations\looks\rifle\R"	
	"..\animations\looks\rifle\LD"
	"..\animations\looks\rifle\D"
	"..\animations\looks\rifle\RD"	
 	blend XR -90 90 loop
	frames 0 1
	}	

$sequence ref_shoot_rifle "..\animations\fires\rifle\LU" {
	"..\animations\fires\rifle\U" 
	"..\animations\fires\rifle\RU" 
	"..\animations\fires\rifle\L" 
	"..\animations\fires\rifle\fire" 
	"..\animations\fires\rifle\R" 
	"..\animations\fires\rifle\LD" 
	"..\animations\fires\rifle\D" 
	"..\animations\fires\rifle\RD" 
	blend XR -90 90
	fps 20
	event 5001 0 "30"
	}

$sequence ref_reload_rifle "..\animations\reloads\ar" 