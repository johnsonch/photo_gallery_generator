<?php
if (!isset($_GET['image'])) {
    header('Location: index.php');
    exit();
}

$imageName = basename($_GET['image']);
$imagePath = $imageName;

if (!file_exists($imagePath) || !getimagesize($imagePath)) {
    header('Location: index.php');
    exit();
}

$mime = mime_content_type($imagePath);
header('Content-Type: ' . $mime);
header('Content-Disposition: attachment; filename="' . $imageName . '"');
header('Content-Length: ' . filesize($imagePath));
readfile($imagePath);
exit();
