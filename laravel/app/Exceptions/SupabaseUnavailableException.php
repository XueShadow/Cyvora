<?php

namespace App\Exceptions;

use RuntimeException;
use Throwable;

class SupabaseUnavailableException extends RuntimeException
{
    public function __construct(?Throwable $previous = null)
    {
        parent::__construct('Supabase is unavailable.', 0, $previous);
    }
}
