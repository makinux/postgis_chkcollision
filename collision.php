<?php
// DB接続
$db = pg_connect("host=localhost dbname=pgis_collision user=postgres password=postgres");

$polygons = $_POST["polygons"];
$matrix_array = array();
foreach($polygons as $val){
	$matrix_array[]="['".$val["id"]."','".$val["positions"]."']";
}
$sql = "SELECT * from getNotCollisionPos(ARRAY[".implode(",",$matrix_array)."])";
$result = pg_query($sql);

$list = array();
while ($row = pg_fetch_assoc($result)) {
	$list[]=$row;
}

echo json_encode($list);

// DB切断
pg_close($link);
