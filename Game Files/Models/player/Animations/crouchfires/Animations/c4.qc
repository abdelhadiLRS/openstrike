$sequence crouch_aim_c4 "..\animations\crouchlooks\c4\LU" {
	"..\animations\crouchlooks\c4\U"
	"..\animations\crouchlooks\c4\RU"	
	"..\animations\crouchlooks\c4\L"
	"..\animations\crouchlooks\c4\crouchlook"
	"..\animations\crouchlooks\c4\R"	
	"..\animations\crouchlooks\c4\LD"
	"..\animations\crouchlooks\c4\D"
	"..\animations\crouchlooks\c4\RD"	
 	blend XR -90 90 loop
	frames 0 1
	origin 0 0 18
	}


$sequence crouch_shoot_c4 "..\animations\crouchfires\c4\crouchfire" origin 0 0 18


$sequence ref_aim_c4 "..\animations\looks\c4\LU" {
	"..\animations\looks\c4\U"
	"..\animations\looks\c4\RU"	
	"..\animations\looks\c4\L"
	"..\animations\looks\c4\look"
	"..\animations\looks\c4\R"	
	"..\animations\looks\c4\LD"
	"..\animations\looks\c4\D"
	"..\animations\looks\c4\RD"	
 	blend XR -90 90 loop
	frames 0 1
	}	

$sequence ref_shoot_c4 "..\animations\fires\c4\fire"

$sequence ref_reload_c4 "..\animations\dummypose"
