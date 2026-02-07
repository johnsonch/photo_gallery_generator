<?php
// Ensure we have an image parameter
if (!isset($_GET['image'])) {
    header('Location: index.php');
    exit();
}

// Get list of all images in the directory
$image_extensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'];
$files = array_filter(scandir('.'), function($file) use ($image_extensions) {
    return in_array(strtolower(pathinfo($file, PATHINFO_EXTENSION)), $image_extensions);
});

// Find current image index and get prev/next
$currentImage = $_GET['image'];
$currentIndex = array_search($currentImage, $files);
$prevImage = $currentIndex > 0 ? $files[$currentIndex - 1] : end($files);
$nextImage = $currentIndex < count($files) - 1 ? $files[$currentIndex + 1] : reset($files);

// Remove any directory traversal attempts
$imageName = basename($_GET['image']);
$imagePath = $imageName; // Look for image in the current directory

// Verify the file exists and is an image
if (!file_exists($imagePath) || !getimagesize($imagePath)) {
    header('Location: index.php');
    exit();
}

// Get image information
$imageInfo = getimagesize($imagePath);
$fileSize = filesize($imagePath);
$fileSizeFormatted = number_format($fileSize / 1024, 2) . ' KB';
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Image Detail</title>
    <link rel="stylesheet" href="styles.css">
</head>
<body>
    <div class="container">
        <div class="image-detail">
            <h1>Image Details</h1>
            <div class="image-info" style="background: #e3f2fd; border-left: 4px solid #2196f3; margin-bottom: 20px;">
                <p style="margin: 0;"><strong>iOS Tip:</strong> To save this image to your Photos, press and hold on the image and choose "Save to Photos"</p>
            </div>

            <div class="image-container">
                <img src="<?php echo htmlspecialchars($imagePath); ?>" alt="Full size image">
            </div>

            <div class="image-info">
                <p><strong>File Name:</strong> <?php echo htmlspecialchars(basename($_GET['image'])); ?></p>
                <p><strong>Dimensions:</strong> <?php echo $imageInfo[0] . 'x' . $imageInfo[1]; ?> pixels</p>
                <p><strong>File Size:</strong> <?php echo $fileSizeFormatted; ?></p>
                <p><strong>Image Type:</strong> <?php echo image_type_to_mime_type($imageInfo[2]); ?></p>
            </div>

            <div class="actions">
                <a href="<?php echo 'image_detail.php?image=' . urlencode($prevImage); ?>" class="nav-btn prev-btn">Previous</a>
                <a href="<?php echo 'download.php?image=' . urlencode($imageName); ?>"
                   class="download-btn">Download Image</a>
                <a href="index.php#<?php echo htmlspecialchars(basename($_GET['image'])); ?>" class="back-btn">Back to Gallery</a>
                <a href="<?php echo 'image_detail.php?image=' . urlencode($nextImage); ?>" class="nav-btn next-btn">Next</a>
            </div>
        </div>
    </div>
</body>
</html>
