<?php

namespace App\Services;

use Appwrite\Client;
use Appwrite\Services\Account;
use Appwrite\Services\TablesDB;
use InvalidArgumentException;
use RuntimeException;

final class AppwriteAdminClient
{
    private Client $client;
    private Account $account;
    private TablesDB $tablesDb;

    public function __construct()
    {
        $endpoint = (string) config('services.appwrite.endpoint');
        $projectId = (string) config('services.appwrite.project_id');
        $apiKey = (string) config('services.appwrite.api_key');

        $this->client = new Client;
        $this->client
            ->setEndpoint($endpoint)
            ->setProject($projectId)
            ->setKey($apiKey)
            ->setTimeout((int) config('services.appwrite.timeout', 5))
            ->setConnectTimeout((int) config('services.appwrite.connect_timeout', 2));

        $this->account = new Account($this->client);
        $this->tablesDb = new TablesDB($this->client);
    }

    public function isConfigured(): bool
    {
        return filled(config('services.appwrite.endpoint'))
            && filled(config('services.appwrite.project_id'))
            && filled(config('services.appwrite.api_key'))
            && filled(config('services.appwrite.database_id'));
    }

    public function account(): Account
    {
        if (! $this->isConfigured()) {
            throw new RuntimeException('Appwrite administrator configuration is incomplete.');
        }

        return $this->account;
    }

    /**
     * @param  array<int, string>  $queries
     * @return array<string, mixed>
     */
    public function listRows(string $tableId, array $queries = []): array
    {
        if (! $this->isConfigured()) {
            throw new RuntimeException('Appwrite administrator configuration is incomplete.');
        }
        $this->assertTableId($tableId);
        $databaseId = (string) config('services.appwrite.database_id');

        return $this->tablesDb->listRows(
            $databaseId,
            $tableId,
            $queries,
        );
    }

    public function getRow(string $tableId, string $rowId): array
    {
        if (! $this->isConfigured()) {
            throw new RuntimeException('Appwrite administrator configuration is incomplete.');
        }
        $this->assertTableId($tableId);

        return $this->tablesDb->getRow(
            (string) config('services.appwrite.database_id'),
            $tableId,
            $rowId,
        );
    }

    private function assertTableId(string $tableId): void
    {
        if (! preg_match('/^[a-zA-Z0-9._-]{1,64}$/', $tableId)) {
            throw new InvalidArgumentException('Invalid Appwrite table ID.');
        }
    }
}
