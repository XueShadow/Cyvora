<?php

namespace App\Exceptions;

use RuntimeException;

class SupabaseRequestException extends RuntimeException
{
    public function __construct(public readonly int $status)
    {
        parent::__construct("Supabase request failed with status {$status}.");
    }
}
