<?php

namespace Tests\Feature;

// use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ExampleTest extends TestCase
{
    /**
     * A basic test example.
     */
    public function test_the_root_route_redirects_to_super_admin_sign_in(): void
    {
        $response = $this->get('/');

        $response->assertRedirect(route('admin.login'));
    }
}
