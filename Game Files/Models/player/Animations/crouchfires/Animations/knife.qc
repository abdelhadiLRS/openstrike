$sequence crouch_aim_knife "..\animations\crouchlooks\knife\LU" {
	"..\animations\crouchlooks\knife\U"
	"..\animations\crouchlooks\knife\RU"	
	"..\animations\crouchlooks\knife\L"
	"..\animations\crouchlooks\knife\crouchlook"
	"..\animations\crouchlooks\knife\R"	
	"..\animations\crouchlooks\knife\LD"
	"..\animations\crouchlooks\knife\D"
	"..\animations\crouchlooks\knife\RD"	
 	blend XR -90 90 loop
	fps 12
	origin 0 0 18
	}


$sequence crouch_shoot_knife  "..\animations\crouchfires\knife\LU" {
	"..\animations\crouchfires\knife\U"
	"..\animations\crouchfires\knife\RU"	
	"..\animations\crouchfires\knife\L"
	"..\animations\crouchfires\knife\crouchfire"
	"..\animations\crouchfires\knife\R"	
	"..\animations\crouchfires\knife\LD"
	"..\animations\crouchfires\knife\D"
	"..\animations\crouchfires\knife\RD"	
 	blend XR -90 90 
	origin 0 0 18
	fps 30
	frames 0 40
	}


$sequence ref_aim_knife "..\animations\looks\knife\LU" {
	"..\animations\looks\knife\U"
	"..\animations\looks\knife\RU"	
	"..\animations\looks\knife\L"
	"..\animations\looks\knife\look"
	"..\animations\looks\knife\R"	
	"..\animations\looks\knife\LD"
	"..\animations\looks\knife\D"
	"..\animations\looks\knife\RD"	
 	blend XR -90 90 loop
	fps 12
	}	

$sequence ref_shoot_knife "..\animations\fires\knife\LU" {
	"..\animations\fires\knife\U"
	"..\animations\fires\knife\RU"	
	"..\animations\fires\knife\L"
	"..\animations\fires\knife\fire"
	"..\animations\fires\knife\R"	
	"..\animations\fires\knife\LD"
	"..\animations\fires\knife\D"
	"..\animations\fires\knife\RD"	
 	blend XR -90 90 loop
	fps 30
	frames 0 40
	}	
