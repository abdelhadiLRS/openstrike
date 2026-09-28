$sequence crouch_aim_shotgun "..\animations\crouchlooks\shotgun\LU" {
	"..\animations\crouchlooks\shotgun\U"
	"..\animations\crouchlooks\shotgun\RU"	
	"..\animations\crouchlooks\shotgun\L"
	"..\animations\crouchlooks\shotgun\crouchlook"
	"..\animations\crouchlooks\shotgun\R"	
	"..\animations\crouchlooks\shotgun\LD"
	"..\animations\crouchlooks\shotgun\D"
	"..\animations\crouchlooks\shotgun\RD"	
 	blend XR -90 90 loop
	frames 0 1
	origin 0 0 18
	}


$sequence crouch_shoot_shotgun "..\animations\crouchfires\shotgun\LU" {
	"..\animations\crouchfires\shotgun\U"
	"..\animations\crouchfires\shotgun\RU"	
	"..\animations\crouchfires\shotgun\L"
	"..\animations\crouchfires\shotgun\crouchfire"
	"..\animations\crouchfires\shotgun\R"	
	"..\animations\crouchfires\shotgun\LD"
	"..\animations\crouchfires\shotgun\D"
	"..\animations\crouchfires\shotgun\RD"	
	blend XR -90 90
	fps 30
	origin 0 0 18
	event 5001 0 "50"
	}

$sequence crouch_reload_shotgun "..\animations\reloads\shotgun"  origin 0 0 18

$sequence ref_aim_shotgun "..\animations\looks\shotgun\LU" {
	"..\animations\looks\shotgun\U"
	"..\animations\looks\shotgun\RU"	
	"..\animations\looks\shotgun\L"
	"..\animations\looks\shotgun\look"
	"..\animations\looks\shotgun\R"	
	"..\animations\looks\shotgun\LD"
	"..\animations\looks\shotgun\D"
	"..\animations\looks\shotgun\RD"	
 	blend XR -90 90 loop
	frames 0 1
	}	

$sequence ref_shoot_shotgun "..\animations\fires\shotgun\LU" {
	"..\animations\fires\shotgun\U" 
	"..\animations\fires\shotgun\RU" 
	"..\animations\fires\shotgun\L" 
	"..\animations\fires\shotgun\fire" 
	"..\animations\fires\shotgun\R" 
	"..\animations\fires\shotgun\LD" 
	"..\animations\fires\shotgun\D" 
	"..\animations\fires\shotgun\RD" 
	blend XR -90 90
	fps 30
	event 5001 0 "50"
	}

$sequence ref_reload_shotgun "..\animations\reloads\shotgun" 