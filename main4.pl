#!/usr/bin/perl 
#use strict;
#use warnings;
use threads;
use threads::shared;
use Thread::Semaphore;
use Thread::Queue;
use lib './Modules/';
use Priority;
#use Date::Parse;

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
            
            my $tlleg = $inicio + time ;
            
            $colaNew->enqueue("--Lector: " . $idHilo, $tlleg);
            listar();
            
            my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($tlleg);
            
            my $linea = localtime . "// Lector  ID: ".$idHilo." T. lleg.: ".$hour.":".$min.":".$sec;
            $linea .= " T. Ejec.: " . $splittedInput[1] . " Delay: ". $inicio . " seg\n" ;
            escribirResume($linea);
            
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
            
            $tlleg = $inicio + time;
            
            $colaNew->enqueue("--Escritor: " . $idHilo , $tlleg);
            listar();
            
            ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($tlleg);
            
            $linea = localtime . "// Escitor ID: ".$idHilo." T. lleg.: ".$hour.":".$min.":".$sec;
            $linea .= " T. Ejec.: " . $splittedInput[1] . " Delay: ".$inicio. " seg\n" ;
            escribirResume($linea);
                        
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

    listar();
        
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

    listar();
           
    my $linea = localtime . "// Ejecutando Lector Id: ".$id . " por: ".$sleep . " seg\n" ;
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

    listar();
             
    $linea = localtime . "// Finalizado Lector Id: ".$id . "\n" ;
    
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

    listar();

    $inSem->down();
    $wrtSem->down();
    
    $colaListos->dequeue();
    $colaEjecucion->enqueue("--Escritor: " . $id );

    listar();

    my $linea = localtime . "// Ejecutando Escritor Id: ".$id . " por: ".$sleep . " seg\n" ;
    escribirLog($linea);
    sleep($sleep);

    $wrtSem->up();
    $inSem->up();
    
    $colaEjecucion->dequeue();
    $colaFinalizados->enqueue("--Escritor: " . $id );

    listar();
    
    $linea = localtime . "// Finalizado Escritor Id: ".$id . "\n" ;
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
    clr();
    print "------LISTADO------------------\n";
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
    print "------------------------------\n";
}

sub inicializar {
  clr();
  open(LECTURA,"> log.txt") || die "No pudo abrirse: $!";
  print LECTURA localtime . "// ---- LOG DE PROCESOS ----\n";
  close(LECTURA);
  
  open(RESUME,"> resume.txt") || die "No pudo abrirse: $!";
  print RESUME localtime .  "// ----  LOG DE CARGA   ----\n";
  close(RESUME);
  
  
}

sub salir {
  clr();
  
  print "Finalizando threads...\n";
      
  foreach (threads->list()) {
    $_->join();
    
  }
 
  print "Hasta la vista baby...\n"
  
}

sub  clr {
          if ($OSNAME eq "MSWin32") {
              system("cls");
          } else { 
              system("clear");
          }
      }

sub escribirResume {
    
    my ($linea) = @_;
     
    open(RESUME,">> resume.txt") || die "No pudo abrirse: $!";
    print RESUME "$linea";
    close(RESUME);
    
}
              
  
