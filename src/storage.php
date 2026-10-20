<?php
// File storage for capsule attachments using AWS S3.

use Aws\S3\S3Client;

/**
 * Инициализация и получение синглтон-клиента S3.
 */
function get_s3_client(): S3Client
{
    static $client = null;
    if ($client === null) {
        $client = new S3Client([
            'version' => 'latest',
            'region'  => $_ENV['AWS_REGION'] ?? $_ENV['AWS_DEFAULT_REGION'] ?? 'eu-central-1',
        ]);
    }
    return $client;
}

/**
 * Сохранение загруженного файла в бакет S3 под ключом uploads/<случайное_имя>.
 */
function storage_save(array $uploadedFile, string $extension): string
{
    $s3 = get_s3_client();
    $bucket = $_ENV['S3_BUCKET'] ?? $_ENV['AWS_BUCKET'] ?? 'timecapsule-dev-uploads-k1tetsssu';

    $storedName = bin2hex(random_bytes(16)) . ($extension !== '' ? '.' . $extension : '');
    $key = 'uploads/' . $storedName;

    $contentType = mime_content_type($uploadedFile['tmp_name']) ?: 'application/octet-stream';

    $s3->putObject([
        'Bucket'      => $bucket,
        'Key'         => $key,
        'SourceFile'  => $uploadedFile['tmp_name'],
        'ContentType' => $contentType,
    ]);

    return $storedName;
}

/**
 * Удаление объекта из бакета S3 по его имени.
 */
function storage_delete(?string $storedName): void
{
    if ($storedName === null || $storedName === '') {
        return;
    }

    $s3 = get_s3_client();
    $bucket = $_ENV['S3_BUCKET'] ?? $_ENV['AWS_BUCKET'] ?? 'timecapsule-dev-uploads-k1tetsssu';

    $s3->deleteObject([
        'Bucket' => $bucket,
        'Key'    => 'uploads/' . basename($storedName),
    ]);
}

/**
 * Перенаправление браузера (HTTP 302) на подписанную ссылку S3 (Presigned URL) со сроком жизни 5 минут.
 */
function storage_stream(string $storedName, string $mime, string $downloadName, string $disposition): void
{
    $s3 = get_s3_client();
    $bucket = $_ENV['S3_BUCKET'] ?? $_ENV['AWS_BUCKET'] ?? 'timecapsule-dev-uploads-k1tetsssu';

    $asciiName = preg_replace('/[^A-Za-z0-9._ -]/', '_', $downloadName);

    $cmd = $s3->getCommand('GetObject', [
        'Bucket'                     => $bucket,
        'Key'                        => 'uploads/' . basename($storedName),
        'ResponseContentType'        => $mime,
        'ResponseContentDisposition' => sprintf(
            '%s; filename="%s"; filename*=UTF-8\'\'%s',
            $disposition,
            $asciiName,
            rawurlencode($downloadName)
        ),
    ]);

    $request = $s3->createPresignedRequest($cmd, '+5 minutes');
    $presignedUrl = (string) $request->getUri();

    header('Location: ' . $presignedUrl, true, 302);
    exit;
}
