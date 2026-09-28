$sequence crouch_aim_onehanded "..\animations\crouchlooks\onehanded\LU" {
	"..\animations\crouchlooks\onehanded\U"
	"..\animations\crouchlooks\onehanded\RU"	
	"..\animations\crouchlooks\onehanded\L"
	"..\animations\crouchlooks\onehanded\crouchlook"
	"..\animations\crouchlooks\onehanded\R"	
	"..\animations\crouchlooks\onehanded\LD"
	"..\animations\crouchlooks\onehanded\D"
	"..\animations\crouchlooks\onehanded\RD"	
 	blend XR -90 90 loop
	frames 0 1
	origin 0 0 18
	}


$sequence crouch_shoot_onehanded "..\animations\crouchfires\onehanded\LU" {
	"..\animations\crouchfires\onehanded\U"
	"..\animations\crouchfires\onehanded\RU"	
	"..\animations\crouchfires\onehanded\L"
	"..\animations\crouchfires\onehanded\crouchfire"
	"..\animations\crouchfires\onehanded\R"	
	"..\animations\crouchfires\onehanded\LD"
	"..\animations\crouchfires\onehanded\D"
	"..\animations\crouchfires\onehanded\RD"	
	blend XR -90 90
	fps 15
	event 5001 0 "10"
	origin 0 0 18
	}

$sequence crouch_reload_onehanded "..\animations\reloads\onehanded crouch" origin 0 0 18

$sequence ref_aim_onehanded "..\animations\looks\onehanded\LU" {
	"..\animations\looks\onehanded\U"
	"..\animations\looks\onehanded\RU"	
	"..\animations\looks\onehanded\L"
	"..\animations\looks\onehanded\look"
	"..\animations\looks\onehanded\R"	
	"..\animations\looks\onehanded\LD"
	"..\animations\looks\onehanded\D"
	"..\animations\looks\onehanded\RD"	
 	blend XR -90 90 loop
	frames 0 1
	}	

$sequence ref_shoot_onehanded "..\animations\fires\onehanded\LU" {
	"..\animations\fires\onehanded\U" 
	"..\animations\fires\onehanded\RU" 
	"..\animations\fires\onehanded\L" 
	"..\animations\fires\onehanded\fire" 
	"..\animations\fires\onehanded\R" 
	"..\animations\fires\onehanded\LD" 
	"..\animations\fires\onehanded\D" 
	"..\animations\fires\onehanded\RD" 
	blend XR -90 90
	fps 15
	event 5001 0 "10"
	}

$sequence ref_reload_onehanded "..\animations\reloads\onehanded" 