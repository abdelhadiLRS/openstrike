// flinches -- we wanted to have more but a last minute bug in studiomdl limited us to two.
// that's why the names are so wierd.
// this is all art that could stand to be improved 

$sequence gut_flinch "..\animations\flinches\generic\LU" {
	"..\animations\flinches\generic\U"
	"..\animations\flinches\generic\RU"	
	"..\animations\flinches\gut\L"
	"..\animations\flinches\gut\look"
	"..\animations\flinches\gut\R"	
	"..\animations\flinches\generic\LD"
	"..\animations\flinches\generic\D"
	"..\animations\flinches\generic\RD"	
 	blend XR -90 90 
	fps 30
	}

$sequence head_flinch "..\animations\flinches\shoulder\L" {
	"..\animations\flinches\shoulder\look"
	"..\animations\flinches\shoulder\R"	
	"..\animations\flinches\head\L"
	"..\animations\flinches\head\look"
	"..\animations\flinches\head\R"	
	"..\animations\flinches\generic\LD"
	"..\animations\flinches\generic\D"
	"..\animations\flinches\generic\RD"	
 	blend XR -90 90 
	fps 30
	}


