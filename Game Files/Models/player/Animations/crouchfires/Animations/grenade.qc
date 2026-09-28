$sequence I_am_a_stupid_placeholder "..\animations\dummypose" loop frames 0 1 origin 0 0 18

$sequence so_am_I "..\animations\dummypose" fps 30 origin 0 0 18


$sequence ref_aim_grenade "..\animations\looks\grenade\LU" {
	"..\animations\looks\grenade\U"
	"..\animations\looks\grenade\RU"	
	"..\animations\looks\grenade\L"
	"..\animations\looks\grenade\look"
	"..\animations\looks\grenade\R"	
	"..\animations\looks\grenade\LD"
	"..\animations\looks\grenade\D"
	"..\animations\looks\grenade\RD"	
 	blend XR -90 90 loop
	fps 20
	}	


$sequence ref_shoot_grenade "..\animations\fires\grenade\LU" {
	"..\animations\fires\grenade\U"
	"..\animations\fires\grenade\RU"	
	"..\animations\fires\grenade\L"
	"..\animations\fires\grenade\fire"
	"..\animations\fires\grenade\R"	
	"..\animations\fires\grenade\LD"
	"..\animations\fires\grenade\D"
	"..\animations\fires\grenade\RD"	
 	blend XR -90 90 
	fps 45
	}	

$sequence crouch_aim_grenade "..\animations\crouchlooks\grenade\LU" {
	"..\animations\crouchlooks\grenade\U"
	"..\animations\crouchlooks\grenade\RU"	
	"..\animations\crouchlooks\grenade\L"
	"..\animations\crouchlooks\grenade\crouchlook"
	"..\animations\crouchlooks\grenade\R"	
	"..\animations\crouchlooks\grenade\LD"
	"..\animations\crouchlooks\grenade\D"
	"..\animations\crouchlooks\grenade\RD"	
 	blend XR -90 90 loop
	fps 20
	}	


$sequence crouch_shoot_grenade "..\animations\crouchfires\grenade\LU" {
	"..\animations\crouchfires\grenade\U"
	"..\animations\crouchfires\grenade\RU"	
	"..\animations\crouchfires\grenade\L"
	"..\animations\crouchfires\grenade\crouchfire"
	"..\animations\crouchfires\grenade\R"	
	"..\animations\crouchfires\grenade\LD"
	"..\animations\crouchfires\grenade\D"
	"..\animations\crouchfires\grenade\RD"	
 	blend XR -90 90 
	fps 45
	}	

