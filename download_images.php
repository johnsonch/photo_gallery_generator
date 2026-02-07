<?php
$image_extensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'];
$zip = new ZipArchive();
$zip_name = 'images_' . date('Y-m-d_H-i-s') . '.zip';

if ($zip->open($zip_name, ZipArchive::CREATE) === TRUE) {
    $files = scandir('.');

    foreach ($files as $file) {
        if ($file === '.' || $file === '..' || $file === 'thumbnails') {
            continue;
        }

        $extension = strtolower(pathinfo($file, PATHINFO_EXTENSION));

        if (in_array($extension, $image_extensions)) {
            $zip->addFile($file);
        }
    }

    $zip->close();

    // Set headers for download
    header('Content-Type: application/zip');
    header('Content-Disposition: attachment; filename="' . $zip_name . '"');
    header('Content-Length: ' . filesize($zip_name));

    // Output the zip file
    readfile($zip_name);

    // Delete the temporary zip file
    unlink($zip_name);
} else {
    echo "Failed to create zip file";
}
?>
