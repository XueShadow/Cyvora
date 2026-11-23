<?php

namespace App\Exceptions;

use RuntimeException;

class SupabaseConfigurationException extends RuntimeException
{
    public function __construct()
    {
        parent::__construct('Supabase server-side configuration is incomplete.');
    }
}
