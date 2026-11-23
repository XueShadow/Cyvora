<?php

namespace App\Exceptions;

use RuntimeException;

class AdminMfaRequiredException extends RuntimeException
{
    public function __construct()
    {
        parent::__construct('Complete the required multi-factor authentication challenge.');
    }
}
