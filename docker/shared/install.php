<?php
// Headless CiviCRM Standalone installer — invoked by the entrypoint after
// the tarball has been extracted.
//
// Args: <appRoot> <dbHost> <dbUser> <dbPass> <dbName> <baseUrl>

[$_, $appRootPath, $dbHost, $dbUser, $dbPass, $dbName, $baseUrl] = $argv + [null, null, null, null, null, null, null];

if (!$appRootPath || !$dbHost || !$dbUser || !$dbPass || !$dbName || !$baseUrl) {
    fwrite(STDERR, "usage: install.php <appRoot> <dbHost> <dbUser> <dbPass> <dbName> <baseUrl>\n");
    exit(64);
}

$settingsPath = $appRootPath . '/private/civicrm.settings.php';
if (file_exists($settingsPath)) {
    unlink($settingsPath);
}

$_SERVER['HTTP_HOST'] = parse_url($baseUrl, PHP_URL_HOST) . (parse_url($baseUrl, PHP_URL_PORT) ? ':' . parse_url($baseUrl, PHP_URL_PORT) : '');
$_SERVER['REQUEST_SCHEME'] = parse_url($baseUrl, PHP_URL_SCHEME) ?: 'http';

require_once $appRootPath . '/core/vendor/autoload.php';
require_once $appRootPath . '/core/CRM/Core/ClassLoader.php';
\CRM_Core_ClassLoader::singleton()->register();
require_once $appRootPath . '/core/setup/civicrm-setup-autoload.php';

\Civi\Setup::assertProtocolCompatibility('1.0');
\Civi\Setup::init([
    'cms'     => 'Standalone',
    'srcPath' => $appRootPath . '/core',
]);

$model = \Civi\Setup::instance()->getModel();
$model->db = $model->cmsDb = [
    'server'   => $dbHost,
    'username' => $dbUser,
    'password' => $dbPass,
    'database' => $dbName,
];
$model->cmsBaseUrl = $baseUrl;
$model->lang = 'en_US';
$model->loadGenerated = TRUE;
$model->syncUsers = TRUE;

$req = \Civi\Setup::instance()->checkRequirements();
$failed = FALSE;
foreach ($req->getMessages() as $m) {
    if (($m['level'] ?? '') === 'error') {
        fwrite(STDERR, "REQ ERROR [{$m['section']}/{$m['name']}]: {$m['message']}\n");
        $failed = TRUE;
    }
}
if ($failed) {
    exit(1);
}

echo "→ installFiles()\n";
\Civi\Setup::instance()->installFiles();

echo "→ installDatabase()\n";
\Civi\Setup::instance()->installDatabase();

echo "DONE\n";
