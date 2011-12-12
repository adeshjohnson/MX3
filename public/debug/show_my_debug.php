

<?
# fast log viewer
# by Kolmisoft 2007


$file = file("mor_debug.txt");

$show_lines = 100;

for ($i=0; $i < $show_lines; $i++){

    $count = count($file) - ($show_lines - $i);
    echo $file[$count];
    echo "<br>";

}    
    
?>