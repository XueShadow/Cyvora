<?php

namespace App\Exceptions;

use RuntimeException;

class AdminAccessDeniedException extends RuntimeException
{
    public function __construct()
    {
        parent::__construct('This account is not authorized for the Super Admin panel.');
    }
}
