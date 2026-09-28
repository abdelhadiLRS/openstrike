$modelname terror\terror
$cd "terror" 

$cdtexture "terror" "packs"
$cliptotextures
$body studio "terror" "packs"
$bodygroup backpack
	{
	blank	
	studio "..\packs\bomb"
	}	

$origin 0 0 36

$include "animations\terrorist shared.qc"