<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>File Browser with Thumbnails</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      font-family: Arial, sans-serif;
      margin: 0;
      padding: 10px;
      background-color: #f9f9f9;
    }

    h1 {
      text-align: center;
      font-size: 24px;
      margin-bottom: 20px;
    }

    .gallery {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(min(600px, 100%), 1fr));
      grid-gap: 10px;
    }

    .gallery a {
      text-decoration: none;
      color: #333;
    }

    .gallery img {
      width: 100%;
      max-width: 600px;
      height: auto;
      aspect-ratio: 1;
      border-radius: 8px;
      box-shadow: 0 2px 5px rgba(0,0,0,0.2);
      object-fit: cover;
    }

    .filename {
      font-size: 12px;
      text-align: center;
      margin-top: 5px;
      word-wrap: break-word;
    }

    .button-container {
      text-align: center;
      margin-bottom: 20px;
      display: flex;
      justify-content: center;
      gap: 10px;
    }

    .button {
      background-color: #4CAF50;
      color: white;
      padding: 10px 20px;
      text-decoration: none;
      border-radius: 5px;
      border: none;
      cursor: pointer;
      font-size: 14px;
    }

    .venmo-button {
      background-color: #008CFF;
    }
  </style>
</head>
<body>
  <h1>File Browser</h1>
  <div style="background: #e3f2fd; border-left: 4px solid #2196f3; padding: 15px; margin-bottom: 20px;">
    <p style="margin: 0;"><strong>Note:</strong> Click any image to view full size and download options</p>
  </div>
  <div class="button-container">
    <a href="download_images.php" class="button">Download All Images</a>
    <a href="%%GALLERY_TIP_URL%%" target="_blank" class="button venmo-button">Support via Tip</a>
  </div>
  <div class="gallery">
    <?php
      $image_extensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'];
      $files = scandir('.');

      foreach ($files as $file) {
        if ($file === '.' || $file === '..') {
          continue;
        }

        $extension = strtolower(pathinfo($file, PATHINFO_EXTENSION));

        if (in_array($extension, $image_extensions)) {
          $thumbnail_path = 'thumbnails/' . $file;
          // Use thumbnail if it exists, otherwise use original image
          $display_image = file_exists($thumbnail_path) ? $thumbnail_path : $file;

          echo '
            <a href="image_detail.php?image=' . urlencode($file) . '" id="' . htmlspecialchars($file) . '">
              <img src="' . htmlspecialchars($display_image) . '" alt="' . htmlspecialchars($file) . '">
              <div class="filename">' . htmlspecialchars($file) . '</div>
            </a>
          ';
        }
      }
    ?>
  </div>
</body>
</html>
