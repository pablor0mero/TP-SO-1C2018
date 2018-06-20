#!/usr/bin/perl 
#use strict;
#use warnings;
use threads;
use threads::shared;
use Thread::Semaphore;
use Thread::Queue;
use lib '.';
use Priority;

### Variables Globales ###

#Variables de menu y contadores
my $salir = 0;
my $idHilo = 0;

# Semaforos y contadores
my $inSem = Thread::Semaphore->new();
my $mxSem = Thread::Semaphore->new();
my $wrtSem = Thread::Semaphore->new();

my $mxColaL = Thread::Semaphore->new();
my $mxColaE = Thread::Semaphore->new();
my $mxColaF = Thread::Semaphore->new();

my $ctr : shared = 0;

my $colaEjecucion = Thread::Queue->new();
my $colaListos = Thread::Queue->new();
my $colaFinalizados = Thread::Queue->new();
my $colaNew = Thread::Queue::Priority->new();



inicializar();

# Comandos disponibles aca
print "Comandos disponibles:\n";
print " - crear-lector [tiempo-lectura] [tiempo-inicio]\n";
print " - crear-escritor [tiempo-escritura] [tiempo-inicio]\n";
print " - listar <[escritores lectores todos]>\n";
print " - salir\n"  ;


while($salir == 0) {
    chomp(my $input = <STDIN>);
    
    my @splittedInput = split / /, $input;
    my $parametersCount = scalar @splittedInput;

    my $command = $splittedInput[0];
        
    if( $command eq "crear-lector") {
        # crear hilo de lector            
        
        $idHilo +=1; 
        my $inicio = 0;

        if($parametersCount < 2) {
            print "Incorrecto: faltan parametros\n";
            return;
        }

        if($parametersCount == 3) {
            $inicio = $splittedInput[2];
        }


        if($splittedInput[1] eq $splittedInput[1]+0 && $inicio eq $inicio+0) {
            
            
            $colaNew->enqueue("--Lector: " . $idHilo, $inicio + time);
            
            #print "En la cola de listos esta: ", $colaListos->peek($idHilo-1) , "\n";
            
            my $t = threads->create('hiloLector', $idHilo, $splittedInput[1], $inicio);
            
            # push @colaEjecucion, $t;
            
        }
        else {
            print 'Parametros incorrectos\n';
            return;
        }
        
    }
    elsif($command eq "crear-escritor") {
        # crear hilo de escritor

        $idHilo +=1;

        my $inicio = 0;

        if($parametersCount < 2) {
            print "Incorrecto: faltan parametros\n";
            return;
        }

        if($parametersCount == 3) {
            $inicio = $splittedInput[2];
        }

        if($splittedInput[1] eq $splittedInput[1]+0 && $inicio eq $inicio+0) {
            
            $colaNew->enqueue("--Escritor: " . $idHilo , $inicio + time);
                        
            my $t = threads->create('hiloEscritor', $idHilo, $splittedInput[1], $inicio);
            #push @colaEjecucion, $t;
        }
        else {
            print 'Parametros incorrectos\n';
            return;
        }
    }
    elsif( $command eq "listar") {
      listar();

    }
    elsif( $command eq "salir") {
        salir();
        $salir = 1;
    }
    else {
        print 'Comando invalido\n';
    }
    
}


sub hiloLector {
      
    my ($id,$sleep, $inicio) = @_;
    my $self = threads->self(); 
    my $tid = $self->tid();
    my $out = $tid;
   
    sleep($inicio);
    $colaNew->dequeue();    
    $colaListos->enqueue("--Lector: " . $id );
        
    $inSem->down();
    $mxSem->down();

    $ctr += 1;
    if($ctr == 1) {
        $wrtSem->down();
    }

    $mxSem->up();
    $inSem->up();
    
    $colaListos->dequeue();
    
    $colaEjecucion->enqueue("--Lector: " . $id );
    
    
    #print "Soy el Hilo Lector Id: ".$id . " , estoy ejecutando: ".$sleep . "seg\n" ;
    my $linea = "Soy el Hilo Lector Id: ".$id . " , estoy ejecutando: ".$sleep . "seg\n" ;
    escribirLog($linea);
    
    sleep($sleep);

    $mxSem->down();

    $ctr -= 1;
    if($ctr == 0) {
        $wrtSem->up();
    }

    $mxSem->up();
    
    $colaEjecucion->dequeue();
    $colaFinalizados->enqueue("--Lector: " . $id );
    
   
    #print "--Lector-id:",$id," Finalizado\n";
    $linea =  "--Lector-id:". $id ." Finalizado\n";
    escribirLog($linea); 
    return $out
}

sub hiloEscritor {
    my ($id,$sleep, $inicio) = @_;
    my $self = threads->self(); # referencia al objeto thread
    my $tid = $self->tid();
    my $out = $tid;

    sleep($inicio);
    $colaNew->dequeue();    
    $colaListos->enqueue("--Escritor: " . $id );

    $inSem->down();
    $wrtSem->down();
    
    $colaListos->dequeue();
    $colaEjecucion->enqueue("--Escritor: " . $id );

    #print "Soy el Hilo Escritor Id: ".$id . " , estoy esribiendo por: ".$sleep . "seg\n";
    my $linea = "Soy el Hilo Escritor Id: ".$id . " , estoy esribiendo por: ".$sleep . "seg\n";
    escribirLog($linea);
    sleep($sleep);

    $wrtSem->up();
    $inSem->up();
    
    $colaEjecucion->dequeue();
    $colaFinalizados->enqueue("--Escritor: " . $id );
    
    #print "Escritor-id:",$id," Finalizado\n";
    $linea = "Escritor-id:".$id." Finalizado\n";
    escribirLog($linea);

    return $out;
   
}


sub escribirLog {
    
    my ($linea) = @_;
     
    open(LECTURA,">> log.txt") || die "No pudo abrirse: $!";
    print LECTURA "$linea";
    close(LECTURA);
    
}

sub listar {
    
    my $i=0;
  
    print "-Nuevos: \n";
    
    
    while ( $i < $colaNew->pending() )
    {
      if ($colaNew->peek($i) ne undef) {
         print $colaNew->peek($i) , "\n"; 
      }
      $i += 1;
     
    }
    
    $i = 0;
    
    print "-Listos: \n";
    
    while ( $i < $colaListos->pending() )
    {
      if ($colaListos->peek($i) ne undef) {
         print $colaListos->peek($i) , "\n"; 
      }
      $i += 1;
     
    }
    
    $i = 0;
    print "-Ejecutando: \n";
    while ( $i < $colaEjecucion->pending() )
    {
      if ($colaEjecucion->peek($i) ne undef) {
         print $colaEjecucion->peek($i) , "\n"; 
      }
     
     $i += 1;
      
    }
    
    $i = 0;
    
    print "-Finalizados: \n";
     while ( $i < $colaFinalizados->pending() )
    {
      if ($colaFinalizados->peek($i) ne undef) {
         print $colaFinalizados->peek($i) , "\n"; 
      }      
     
      $i += 1;
    }    
    
}

sub inicializar {
  
  open(LECTURA,"> log.txt") || die "No pudo abrirse: $!";
  print LECTURA "--- INICIO DE PROGRAMA ---\n";
  close(LECTURA);
  
  
}

sub salir {
  
  
  print "Hasta la vista baby...\n"
  
}
  
